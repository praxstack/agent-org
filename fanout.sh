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
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
CONCURRENCY="${FANOUT_CONCURRENCY:-3}"   # bounded (failure-mode research: ≤3)

PROMPT_FILE="${1:?prompt file}"; RUN_ID="${2:?run_id}"; ROLES="${3:-$SCRIPT_DIR/roles.toml}"
RUN_DIR="${AGENT_ORG_RUNS:-/tmp}/$RUN_ID"; mkdir -p "$RUN_DIR"
ledger_init "$RUN_ID" "$RUN_DIR/ledger.jsonl"

[ -f "$ROLES" ] || { printf 'correctness=sonnet\nsimplicity=sonnet\nsecurity=sonnet\n' > "$ROLES"; }

spawn_one() { # role model
  local role="$1" model="$2" out="$RUN_DIR/leaf-$role.json"
  ledger_event fanout "$role" "$model" spawn "$(cat "$PROMPT_FILE")" "" ""
  "$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" --model "$model" --output-format json \
      --permission-mode plan > "$out" 2>"$RUN_DIR/leaf-$role.err" || true
  # extract result text (jq if present), detect malformed -> that leaf FAILED (PR-2.2)
  local res verdict
  if command -v jq >/dev/null 2>&1; then res="$(jq -r '.result // empty' "$out" 2>/dev/null)"; else res="$(cat "$out" 2>/dev/null)"; fi
  if [ -z "$res" ]; then verdict=FAIL-malformed; else verdict=ok; fi
  ledger_event fanout "$role" "$model" result "$(cat "$PROMPT_FILE")" "$res" "$verdict"
  echo "  leaf $role ($model): $verdict"
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
