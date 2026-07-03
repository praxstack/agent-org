#!/usr/bin/env bash
# fanout.sh — v2 multi-model subagent fan-out (intra-session scope).
# Spawns N subagents IN ONE PROCESS, each a (possibly) different model per role,
# joins them via the LEDGER (not pipes), and tolerates one bad leaf (PR-2.2).
# Roles + models come from roles.toml (declarative; model-per-role is config not code).
#
# Usage: fanout.sh <prompt-file> <run_id> [roles.toml]
#   roles.toml lines:  <role>=<model>     (e.g. correctness=opus)
# Each role gets the same prompt, tagged with its role; results land in the ledger.
set -uo pipefail
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/ledger.sh"
. "$SCRIPT_DIR/lib/verdict.sh"   # cross-runner verdict normalization
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
CONCURRENCY="${FANOUT_CONCURRENCY:-3}"   # bounded (failure-mode research: ≤3)

PROMPT_FILE="${1:?prompt file}"; RUN_ID="${2:?run_id}"; ROLES="${3:-$SCRIPT_DIR/roles.toml}"
RUN_DIR="${AGENT_ORG_RUNS:-/tmp}/$RUN_ID"; mkdir -p "$RUN_DIR"
ledger_init "$RUN_ID" "$RUN_DIR/ledger.jsonl"

[ -f "$ROLES" ] || { printf 'correctness=sonnet\nsimplicity=sonnet\nsecurity=sonnet\n' > "$ROLES"; }

HERMES_BIN="${HERMES_BIN:-$(command -v hermes 2>/dev/null || echo hermes)}"

spawn_one() { # role model
  # A leaf's runner is chosen by the model token. A "hermes:" prefix (e.g.
  # hermes:anthropic/claude-sonnet-4.6 or bare "hermes") routes to the Hermes
  # agent CLI; anything else is a claude --model. Cross-runner fan-out is the
  # point: heterogeneous agents, one ledger join (architecture conviction #1).
  local role="$1" model="$2"
  local out="$RUN_DIR/leaf-$role.json" res verdict
  ledger_event fanout "$role" "$model" spawn "$(cat "$PROMPT_FILE")" "" ""
  case "$model" in
    hermes|hermes:*)
      # Hermes -z prints ONLY the result text (no JSON wrapper) -> capture raw.
      local hmodel="${model#hermes}"; hmodel="${hmodel#:}"
      if [ -n "$hmodel" ]; then
        "$HERMES_BIN" -z "$(cat "$PROMPT_FILE")" -m "$hmodel" --yolo \
            > "$out" 2>"$RUN_DIR/leaf-$role.err" || true
      else
        "$HERMES_BIN" -z "$(cat "$PROMPT_FILE")" --yolo \
            > "$out" 2>"$RUN_DIR/leaf-$role.err" || true
      fi
      res="$(cat "$out" 2>/dev/null)"
      ;;
    *)
      "$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" --model "$model" --output-format json \
          --permission-mode plan > "$out" 2>"$RUN_DIR/leaf-$role.err" || true
      # extract result text (jq if present), detect malformed -> that leaf FAILED (PR-2.2)
      if command -v jq >/dev/null 2>&1; then res="$(jq -r '.result // empty' "$out" 2>/dev/null)"; else res="$(cat "$out" 2>/dev/null)"; fi
      ;;
  esac
  if [ -z "$res" ]; then verdict=FAIL-malformed; else verdict=ok; fi
  # NORMALIZE: collapse this leaf (claude-JSON or hermes-raw) to the canonical
  # VOICE/VERDICT/FINDINGS block so a chair can synthesize across runners. The
  # normalized token (PASS|FAIL|UNPARSEABLE) is recorded as the leaf's gate_result.
  verdict_normalize "$out" > "$RUN_DIR/verdict-$role.txt"
  local vtok; vtok="$(grep -m1 '^VERDICT:' "$RUN_DIR/verdict-$role.txt" | awk '{print $2}')"
  [ "$verdict" = FAIL-malformed ] && vtok=UNPARSEABLE
  ledger_event fanout "$role" "$model" result "$(cat "$PROMPT_FILE")" "$res" "$vtok"
  echo "  leaf $role ($model): transport=$verdict verdict=$vtok"
}

# launch with bounded concurrency
n=0
while IFS='=' read -r role model; do
  [ -z "$role" ] && continue
  spawn_one "$role" "$model" &
  n=$((n+1)); [ $(( n % CONCURRENCY )) -eq 0 ] && wait
done < "$ROLES"
wait

# summary from the ledger (the join point — not pipes)
echo "spawned=$(ledger_count spawn) results=$(ledger_count result) malformed=$(grep -c 'FAIL-malformed' "$RUN_DIR/ledger.jsonl" 2>/dev/null || echo 0)"
echo "ledger: $RUN_DIR/ledger.jsonl"

# CHAIR: synthesize the normalized per-leaf verdicts into ONE consolidated verdict
# (strict council rule: PASS iff every leaf is PASS). This is the join that makes
# cross-runner fan-out actionable — a single verdict.txt regardless of which runner
# produced each leaf. Deterministic (no extra LLM call); pure aggregation.
shopt -s nullglob
leaf_verdicts=( "$RUN_DIR"/verdict-*.txt )
shopt -u nullglob
if [ "${#leaf_verdicts[@]}" -gt 0 ]; then
  overall="$(verdict_aggregate "${leaf_verdicts[@]/#/}")"
  # build a consolidated, deduped FINDINGS section from non-PASS leaves
  {
    echo "VERDICT: $overall"
    echo "REASON: strict council — PASS iff all ${#leaf_verdicts[@]} leaves PASS"
    echo "VOICES:"
    for vf in "${leaf_verdicts[@]}"; do
      r="$(basename "$vf" .txt)"; r="${r#verdict-}"
      echo "- $r: $(grep -m1 '^VERDICT:' "$vf" | awk '{print $2}')"
    done
    if [ "$overall" != PASS ]; then
      echo "CHANGES_REQUIRED:"
      for vf in "${leaf_verdicts[@]}"; do
        tok="$(grep -m1 '^VERDICT:' "$vf" | awk '{print $2}')"
        [ "$tok" = PASS ] && continue
        r="$(basename "$vf" .txt)"; r="${r#verdict-}"
        awk 'BEGIN{p=0} /^FINDINGS:/{p=1;next} p{print}' "$vf" | sed "s/^/  [$r] /"
      done
    fi
  } > "$RUN_DIR/verdict.txt"
  echo "consolidated verdict: $(grep -m1 '^VERDICT:' "$RUN_DIR/verdict.txt" | awk '{print $2}')  ($RUN_DIR/verdict.txt)"
fi
