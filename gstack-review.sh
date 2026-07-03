#!/usr/bin/env bash
# gstack-review.sh — HETEROGENEOUS review council, the gstack "code-review-expert
# <-> receive-code-review <-> fix" loop, run to convergence ("no fixes").
#
# This is an agent-org v-ladder expansion piece. It is the inner review stage of
# the larger gstack state machine (expand->poc->review->implement->[review<->fix]*
# ->improve->push) — built first because E1 left exactly ONE promising hypothesis
# untested: a council of DIFFERENT agent families (claude + codex + hermes) may
# catch what a homogeneous council can't, because their blind spots differ.
#
# Topology (unchanged agent-org invariants):
#   TREE not mesh         — driver spawns coder + each voice; no agent-to-agent cycle.
#   CONTRACTS not history — voices see the diff + their lens only; coder gets the
#                           consolidated, normalized verdict, not transcripts.
#   SINGLE-THREADED WRITE  — only the driver commits, only after a PASS.
#   GATE OUTSIDE WORKER    — optional VERIFY_CMD runs deterministically (clean cwd).
#   LOOP-UNTIL-CONVERGED   — coder<->council repeats until PASS or MAX_ROUNDS.
#
# Council members are declared in a panel file (default: review-panel.toml):
#   <lens>=<runner-token>    e.g.  correctness=claude:sonnet
#                                  security=hermes
#                                  review=codex            (codex's native reviewer voice)
# Each lens is a BLIND voice; the chair (lib/verdict.sh, deterministic) aggregates
# strictly: PASS iff every voice PASS. No extra LLM chair call — pure aggregation.
#
# Usage:
#   ./gstack-review.sh "<task>" [repo] [panel.toml]
# Env:
#   CODER          coder runner token   (default: claude:sonnet)
#   MAX_ROUNDS     default 4
#   VERIFY_CMD     optional deterministic gate (run from clean cwd)
#   REVIEW_ONLY=1  skip the coder; just review the repo's current staged diff once
set -uo pipefail

_src="${BASH_SOURCE[0]}"
while [ -h "$_src" ]; do _d="$(cd -P "$(dirname "$_src")" && pwd)"; _src="$(readlink "$_src")"; [[ "$_src" != /* ]] && _src="$_d/$_src"; done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"
. "$SCRIPT_DIR/lib/ledger.sh"
. "$SCRIPT_DIR/lib/verdict.sh"
. "$SCRIPT_DIR/lib/runner.sh"

TASK="${1:?usage: gstack-review.sh \"<task>\" [repo] [panel.toml]}"
REPO="${2:-$PWD}"
PANEL="${3:-$SCRIPT_DIR/review-panel.toml}"
CODER="${CODER:-claude:sonnet}"
MAX_ROUNDS="${MAX_ROUNDS:-4}"
RUNS_ROOT="${AGENT_ORG_RUNS:-$SCRIPT_DIR/runs}"
HOOK="${BLOCK_COMMIT_HOOK:-$SCRIPT_DIR/hooks/block-commit.sh}"

[ -f "$PANEL" ] || printf 'correctness=claude:sonnet\nsecurity=hermes\nsimplicity=pi\n' > "$PANEL"

RUN_DIR="$RUNS_ROOT/gstack-$$"; mkdir -p "$RUN_DIR"
ledger_init "gstack-$$" "$RUN_DIR/ledger.jsonl"
cd "$REPO" || { echo "FATAL: cannot cd $REPO" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FATAL: $REPO is not a git repo" >&2; exit 1; }
echo "run: $RUN_DIR | coder=$CODER panel=$PANEL repo=$REPO"
echo "panel:"; sed 's/^/  /' "$PANEL"

# coder runs under the commit-gate hook (claude only; other coders are gated by
# the fact that the DRIVER is the sole committer regardless).
CODER_SETTINGS="$RUN_DIR/coder-settings.json"
cat > "$CODER_SETTINGS" <<JSON
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "$HOOK" } ] } ] } }
JSON

# council_review <diff-file> <round> -> writes $RUN_DIR/verdict.txt (normalized).
council_review() {
  local diff="$1" round="$2" lens runner pids=()
  while IFS='=' read -r lens runner; do
    [ -z "$lens" ] && continue
    local lensdesc
    case "$lens" in
      correctness) lensdesc="Correct logic, real edge/boundary cases, off-by-one, null/empty handling, does it actually satisfy the task and do tests cover behavior?" ;;
      simplicity)  lensdesc="Simplest design that works (DHH bar): dead code, duplication, over-engineering, loose equality, poor naming, style mismatch." ;;
      security)    lensdesc="Injection (SQL/command), hardcoded secrets, unsafe shell/eval, auth/signature bypass, destructive ops without guards, data loss." ;;
      review)      lensdesc="Full code review: any defect across correctness, security, and maintainability. Be exhaustive and concrete." ;;
      *)           lensdesc="Review this diff for defects on the '$lens' concern." ;;
    esac
    cat > "$RUN_DIR/voice-$lens.prompt" <<EOF
You are the $lens reviewer on a code-review council. Judge ONLY this lens:
$lensdesc

You see the diff in isolation; other reviewers cover other lenses. Be strict on YOUR lens.
TASK: $TASK
--- DIFF ---
$(cat "$diff")
--- END DIFF ---
Reply in EXACTLY this format and nothing else:
VOICE: $lens
VERDICT: PASS  (or)  FAIL
FINDINGS:
- <each concrete issue on your lens; omit if PASS>
EOF
    ledger_event review "$lens" "$runner" spawn "$(cat "$diff")" "" ""
    ( run_agent "$runner" "$RUN_DIR/voice-$lens.prompt" "$RUN_DIR/voice-$lens.out"
      verdict_normalize "$RUN_DIR/voice-$lens.out" > "$RUN_DIR/verdict-$lens.txt"
      tok="$(grep -m1 '^VERDICT:' "$RUN_DIR/verdict-$lens.txt" | awk '{print $2}')"
      ledger_event review "$lens" "$runner" result "" "$(cat "$RUN_DIR/verdict-$lens.txt")" "$tok"
      echo "  voice $lens ($runner): $tok" ) &
    pids+=($!)
  done < "$PANEL"
  for p in "${pids[@]}"; do wait "$p"; done

  # CHAIR (deterministic aggregation via lib/verdict.sh): PASS iff all voices PASS.
  shopt -s nullglob; local vfs=( "$RUN_DIR"/verdict-*.txt ); shopt -u nullglob
  local overall; overall="$(verdict_aggregate "${vfs[@]}")"
  {
    echo "VERDICT: $overall"
    echo "REASON: heterogeneous council (round $round) — PASS iff all ${#vfs[@]} voices PASS"
    echo "VOICES:"
    for vf in "${vfs[@]}"; do
      r="$(basename "$vf" .txt)"; r="${r#verdict-}"
      echo "- $r: $(grep -m1 '^VERDICT:' "$vf" | awk '{print $2}')"
    done
    if [ "$overall" != PASS ]; then
      echo "CHANGES_REQUIRED:"
      for vf in "${vfs[@]}"; do
        tok="$(grep -m1 '^VERDICT:' "$vf" | awk '{print $2}')"; [ "$tok" = PASS ] && continue
        r="$(basename "$vf" .txt)"; r="${r#verdict-}"
        awk 'BEGIN{p=0} /^FINDINGS:/{p=1;next} p{print}' "$vf" | sed "/^- (none)$/d; s/^/  [$r] /"
      done
    fi
  } > "$RUN_DIR/verdict.txt"
}

round=0
while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  echo "===== ROUND $round / $MAX_ROUNDS ====="

  if [ "${REVIEW_ONLY:-0}" != "1" ]; then
    # CODER stage (gated). First round = task; later = consolidated change list.
    if [ "$round" -eq 1 ]; then
      cat > "$RUN_DIR/coder.prompt" <<EOF
You are the CODER (pe-grade: high bar, ownership). Implement this task in the repo:

$TASK

STANDARDS: match surrounding style; simplest design that fully solves it; handle real
edge cases; no security footguns; tests cover happy + failure paths; leave the tree clean.
RULES: you are GATED (a hook blocks git commit/push). Make changes, run tests, \`git add -A\`,
then STOP with a "DIFF SUMMARY:". If genuinely blocked on a human decision, reply with one
line "NEEDS_HUMAN: <question>" and make no changes.
EOF
    else
      cat > "$RUN_DIR/coder.prompt" <<EOF
The review council requested changes. Address EVERY point, re-run tests, \`git add -A\`, STOP.
Do not commit.

COUNCIL VERDICT:
$(cat "$RUN_DIR/verdict.txt")
EOF
    fi
    echo "-- coder ($CODER) --"
    run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out"
    if grep -qE '^NEEDS_HUMAN:' "$RUN_DIR/coder.out"; then
      echo "===== HUMAN GATE: $(grep -m1 '^NEEDS_HUMAN:' "$RUN_DIR/coder.out")"; exit 5
    fi
    git add -A 2>/dev/null
  fi

  git --no-pager diff --cached > "$RUN_DIR/round-$round.diff"
  if [ ! -s "$RUN_DIR/round-$round.diff" ]; then
    echo "!! no staged diff this round — stopping." >&2; exit 3
  fi

  # DETERMINISTIC GATE (optional, unfakeable): runs from clean cwd, scrubbed env.
  if [ -n "${VERIFY_CMD:-}" ]; then
    echo "-- deterministic gate --"
    if ( cd / && env -u PYTHONPATH -u PYTHONSTARTUP -u PYTHONHOME bash -c "$VERIFY_CMD" ) > "$RUN_DIR/verify-$round.log" 2>&1; then
      echo "  ✓ VERIFY_CMD passed"
    else
      echo "  ✗ VERIFY_CMD failed — auto-reject, feeding output to coder"
      { echo "VERDICT: FAIL"; echo "REASON: deterministic gate failed (machine-checked)"; echo "CHANGES_REQUIRED:"; tail -30 "$RUN_DIR/verify-$round.log" | sed 's/^/  /'; } > "$RUN_DIR/verdict.txt"
      [ "${REVIEW_ONLY:-0}" = "1" ] && { cat "$RUN_DIR/verdict.txt"; exit 1; }
      continue
    fi
  fi

  echo "-- council reviewing --"
  council_review "$RUN_DIR/round-$round.diff" "$round"
  cat "$RUN_DIR/verdict.txt"

  if grep -qE '^VERDICT:[[:space:]]*PASS' "$RUN_DIR/verdict.txt"; then
    echo "===== COUNCIL: no fixes (PASS) on round $round ====="
    if [ "${REVIEW_ONLY:-0}" = "1" ]; then echo "(review-only: not committing)"; exit 0; fi
    git commit -q -m "feat: $TASK

Reviewed-by: gstack heterogeneous council ($(awk -F= '{printf "%s=%s ",$1,$2}' "$PANEL")), round $round
Co-Authored-By: agent-org coder ($CODER)" && echo "committed." || echo "(commit skipped)"
    echo "artifacts: $RUN_DIR"; exit 0
  fi
  [ "${REVIEW_ONLY:-0}" = "1" ] && { echo "(review-only: council requested changes; stopping)"; exit 1; }
  echo "-- council requested changes; looping --"
done
echo "!! MAX_ROUNDS ($MAX_ROUNDS) without PASS — human gate. artifacts: $RUN_DIR" >&2
exit 4
