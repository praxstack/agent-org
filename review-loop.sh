#!/usr/bin/env bash
# review-loop.sh — the Stage-1 reviewer<->coder gated loop.
#
# THE PROVEN UNIT (per Anthropic + Cognition 2026 convergence): a CODER agent
# writes code but is GATED — it physically cannot commit (block-commit.sh hook).
# It produces a staged diff and stops. A REVIEWER agent (a DIFFERENT model) reads
# the diff, returns a structured pass/fail verdict + comments. On fail, the coder
# is resumed with the reviewer's comments and loops. On pass, the driver commits.
#
# This replaces hand-babysitting two sessions: you start it and walk away; it
# stops only on PASS, on max rounds, or on an explicit human-gate request.
#
# Design choices grounded in the failure-mode research:
#   - TREE not mesh: driver -> coder, driver -> reviewer. No agent-to-agent cycle.
#   - CONTRACTS not histories: the coder gets the reviewer's STRUCTURED verdict,
#     not its whole transcript (avoids context-loss/bleed across handoffs).
#   - HARD EXIT: MAX_ROUNDS cap + per-call budget, so no infinite "$700 loop".
#   - SINGLE-THREADED WRITES: only the driver commits, only after a PASS.
#   - DIFFERENT MODELS: coder and reviewer are deliberately different models so
#     the reviewer isn't blind to the coder's own blind spots.
#
# Usage:
#   ./review-loop.sh "<task description>"   [path/to/repo]
#
# Env overrides:
#   CODER_MODEL     (default: sonnet)   — the implementer
#   REVIEWER_MODEL  (default: opus)     — the stronger/independent reviewer
#   MAX_ROUNDS      (default: 5)
#   CLAUDE_BIN      (default: resolved real binary, NOT the yolo shell function)

set -uo pipefail

# --- portable self-location (works wherever the repo is cloned) -------------
# SCRIPT_DIR = the dir this file lives in, resolving symlinks. All sibling
# paths (the hook, the runs dir) are derived from it so the tool is not tied
# to any one machine. Override CLAUDE_BIN / AGENT_ORG_RUNS via env if needed.
_src="${BASH_SOURCE[0]}"
while [ -h "$_src" ]; do _dir="$(cd -P "$(dirname "$_src")" && pwd)"; _src="$(readlink "$_src")"; [[ "$_src" != /* ]] && _src="$_dir/$_src"; done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"
HOOK="${BLOCK_COMMIT_HOOK:-$SCRIPT_DIR/hooks/block-commit.sh}"
# CLAUDE_BIN: prefer an explicit override, else the user's claude on PATH.
# (The interactive `claude` shell function isn't available in a script, so we
# resolve the binary; `command -v claude` finds it on most installs.)
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")}"
RUNS_ROOT="${AGENT_ORG_RUNS:-$SCRIPT_DIR/runs}"

# --- human-gate resume mode -------------------------------------------------
# Invoked as:  HUMAN_ANSWER="..." CODER_SID=... ./review-loop.sh --resume-human <RUN_DIR> <TASK> <REPO>
# Feeds the operator's answer back into the paused coder session, lets it produce
# the diff, then hands off to a fresh reviewer loop on the same repo. This closes
# the human-in-the-loop gate: the org asked its CEO (you), got an answer, resumes.
if [ "${1:-}" = "--resume-human" ]; then
  RH_RUN="${2:?need RUN_DIR}"; RH_TASK="${3:?need task}"; RH_REPO="${4:-$PWD}"
  : "${HUMAN_ANSWER:?set HUMAN_ANSWER=\"...\"}"
  : "${CODER_SID:?set CODER_SID=<the session id printed at the gate>}"
  CODER_MODEL="${CODER_MODEL:-sonnet}"
  cd "$RH_REPO" || { echo "FATAL: cannot cd $RH_REPO" >&2; exit 1; }
  cat > "$RH_RUN/coder-settings.json" <<JSON
{ "hooks": { "PreToolUse": [ {
    "matcher": "Bash",
    "hooks": [ { "type": "command", "command": "$HOOK" } ]
} ] } }
JSON
  echo "===== HUMAN ANSWER received — resuming coder session $CODER_SID ====="
  "$CLAUDE_BIN" -p "The operator answered your question: $HUMAN_ANSWER

Now implement the task accordingly. You are still GATED (cannot commit): make the
changes, run tests, \`git add -A\`, and STOP with a DIFF SUMMARY." \
      --model "$CODER_MODEL" --output-format json --permission-mode acceptEdits \
      --resume "$CODER_SID" --settings "$RH_RUN/coder-settings.json" \
      > "$RH_RUN/coder.resumed.json" 2>"$RH_RUN/coder.resumed.err" || true
  git -C "$RH_REPO" add -A 2>/dev/null
  echo "Coder resumed and staged changes. Re-run the normal loop to review:"
  echo "  $0 \"$RH_TASK\" \"$RH_REPO\""
  echo "(the staged work is ready; the next normal run's reviewer will judge it)"
  exit 0
fi

TASK="${1:?usage: review-loop.sh \"<task>\" [repo]}"
REPO="${2:-$PWD}"
CODER_MODEL="${CODER_MODEL:-sonnet}"
REVIEWER_MODEL="${REVIEWER_MODEL:-opus}"
MAX_ROUNDS="${MAX_ROUNDS:-5}"

# PERM_MODE: how the headless coder handles tool permissions.
#   default  acceptEdits  — auto-approves Edits, but PROMPTS on Bash. In a
#                           headless `claude -p` session there is no TTY to
#                           answer that prompt, so the coder HANGS the moment it
#                           needs Bash (git add / run tests). This is the silent
#                           stall mode.
#   YOLO=1   --dangerously-skip-permissions — never prompts, so the coder runs
#                           tests + git add unattended. The commit-gate hook
#                           still runs (PreToolUse hooks fire regardless), so the
#                           coder STILL cannot commit — only prompts are skipped.
if [ "${YOLO:-0}" = "1" ]; then
  PERM_ARGS=(--dangerously-skip-permissions)
  echo "YOLO=1 — coder/reviewer run with --dangerously-skip-permissions (no prompts; commit-gate hook still enforced)"
else
  PERM_ARGS=(--permission-mode acceptEdits)
fi

[ -x "$CLAUDE_BIN" ] || { echo "FATAL: claude binary not found at $CLAUDE_BIN" >&2; exit 1; }

RUN_DIR="$RUNS_ROOT/run-$$"
mkdir -p "$RUN_DIR"
echo "run dir: $RUN_DIR  | coder=$CODER_MODEL reviewer=$REVIEWER_MODEL repo=$REPO"

cd "$REPO" || { echo "FATAL: cannot cd $REPO" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FATAL: $REPO is not a git repo" >&2; exit 1; }

# A temporary settings file that installs the commit-gate hook for the CODER only.
CODER_SETTINGS="$RUN_DIR/coder-settings.json"
cat > "$CODER_SETTINGS" <<JSON
{ "hooks": { "PreToolUse": [ {
    "matcher": "Bash",
    "hooks": [ { "type": "command", "command": "$HOOK" } ]
} ] } }
JSON

# --- helpers ---------------------------------------------------------------

# run_claude <model> <session-tag> <prompt-file> <extra-flags...>
# Captures the session_id so we can --resume the SAME agent next round (this is
# the "wait like an event handler" substitute: the agent's context persists).
run_claude() {
  local model="$1" tag="$2" promptfile="$3"; shift 3
  local sidfile="$RUN_DIR/$tag.sid" outfile="$RUN_DIR/$tag.out.json"
  local resume_args=()
  [ -s "$sidfile" ] && resume_args=(--resume "$(cat "$sidfile")")

  # bash 3.2 + `set -u` errors on "${arr[@]}" when arr is empty; the
  # "${arr[@]+"${arr[@]}"}" idiom expands to nothing safely when unset.
  "$CLAUDE_BIN" -p "$(cat "$promptfile")" \
      --model "$model" \
      --output-format json \
      "${PERM_ARGS[@]}" \
      "${resume_args[@]+"${resume_args[@]}"}" "$@" > "$outfile" 2>"$RUN_DIR/$tag.err" || true

  # Persist session_id for next round; emit the result text.
  if command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // empty' "$outfile" > "$sidfile" 2>/dev/null
    jq -r '.result // .text // empty' "$outfile" 2>/dev/null
  else
    grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$outfile" | head -1 | sed -E 's/.*"([^"]*)"$/\1/' > "$sidfile"
    cat "$outfile"
  fi
}

# --- the loop --------------------------------------------------------------

round=0
while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  echo "===== ROUND $round / $MAX_ROUNDS ====="

  # 1) CODER works (gated: cannot commit). First round = the task; later rounds
  #    = the reviewer's change-requests (resumed session keeps prior context).
  if [ "$round" -eq 1 ]; then
    cat > "$RUN_DIR/coder.prompt" <<EOF
You are the CODER. Implement this task in the current repo:

$TASK

ENGINEERING STANDARDS (you are held to these; the reviewers will check them):
- Match the surrounding code's style, naming, and idioms — read neighboring files first.
- Simplest design that fully solves it (DHH/simplicity bar): no speculative abstraction,
  no dead code, no over-engineering. Delete more than you add where you can.
- Handle the real edge cases (empty/null/boundary/error paths), not just the happy path.
- No security footguns: validate input, no injection, no secrets in code, least privilege.
- Tests are part of "done": cover the happy path AND the failure/edge cases you handle.
- Leave the tree clean: no debug prints, no stray files, no build cruft.

RULES:
- You are GATED: you cannot and must not commit (a hook blocks git commit/push).
- Make the changes, run the project's tests, then \`git add -A\` and STOP.
- End your reply with a section "DIFF SUMMARY:" describing what you changed and why,
  and a "STANDARDS:" line noting how you met simplicity/edge-cases/security/tests.
- IF the task is genuinely ambiguous and you cannot proceed without a human
  decision, do NOT guess. Instead make NO code changes and reply with a single
  line starting exactly: "NEEDS_HUMAN: <your question>" — the loop will pause
  and route your question to the operator. Use this ONLY for real blockers.
EOF
  else
    cat > "$RUN_DIR/coder.prompt" <<EOF
The REVIEWER rejected the previous diff. Address EVERY point below, then
re-run tests, \`git add -A\`, and STOP. Do not commit.

REVIEWER VERDICT:
$(cat "$RUN_DIR/verdict.txt")
EOF
  fi
  echo "-- coder working ($CODER_MODEL) --"
  run_claude "$CODER_MODEL" coder "$RUN_DIR/coder.prompt" \
      --settings "$CODER_SETTINGS" > "$RUN_DIR/coder.reply.txt"
  tail -5 "$RUN_DIR/coder.reply.txt"

  # 1b) HUMAN GATE: if the coder raised a blocking question, pause for the
  #     operator instead of looping blindly (the "question asking" scenario).
  #     This is the human-in-the-loop gate — the org escalates to its CEO (you)
  #     rather than guessing. Exit 5 = waiting on a human decision.
  if grep -qE '^NEEDS_HUMAN:' "$RUN_DIR/coder.reply.txt"; then
    q="$(grep -E '^NEEDS_HUMAN:' "$RUN_DIR/coder.reply.txt" | head -1 | sed -E 's/^NEEDS_HUMAN:[[:space:]]*//')"
    echo "===== HUMAN GATE (round $round): the coder needs a decision ====="
    echo "QUESTION: $q"
    echo "$q" > "$RUN_DIR/human-question.txt"
    echo "Answer with:  HUMAN_ANSWER=\"<your answer>\" CODER_SID=$(cat "$RUN_DIR/coder.sid" 2>/dev/null) \\"
    echo "  $0 --resume-human \"$RUN_DIR\" \"$TASK\" \"$REPO\""
    echo "(loop paused — no guessing. artifacts: $RUN_DIR)"
    exit 5
  fi

  # 2) Capture the staged diff — the CONTRACT handed to the reviewer.
  #    Keep build cruft out of the gate: ensure common caches are ignored so the
  #    reviewer judges real code and the commit never includes .pyc/__pycache__.
  if [ ! -f "$REPO/.gitignore" ] || ! grep -q '__pycache__' "$REPO/.gitignore" 2>/dev/null; then
    printf '__pycache__/\n*.pyc\n.pytest_cache/\n.venv/\nnode_modules/\n' >> "$REPO/.gitignore"
  fi
  git add -A 2>/dev/null
  # Purge any ignored cruft that is staged — robust to an ALREADY-POLLUTED index
  # (git add -A re-stages files git already tracks even if newly .gitignore'd).
  # `git ls-files -ci --exclude-standard` lists exactly the staged paths that the
  # ignore rules say should NOT be tracked; unstage each with --cached (keeps the
  # file on disk). This is the fix for the pycache-leak the reviewer caught.
  ignored_staged="$(git ls-files -ci --exclude-standard 2>/dev/null)"
  if [ -n "$ignored_staged" ]; then
    printf '%s\n' "$ignored_staged" | while IFS= read -r f; do
      [ -n "$f" ] && git rm -r --cached --quiet -- "$f" 2>/dev/null || true
    done
  fi
  git --no-pager diff --cached > "$RUN_DIR/round-$round.diff"
  if [ ! -s "$RUN_DIR/round-$round.diff" ]; then
    echo "!! coder produced no staged diff this round — stopping for human review." >&2
    exit 3
  fi

  # 2b) DETERMINISTIC GATE (the anti-greenwash core): if the operator supplied a
  #     VERIFY_CMD, the SCRIPT runs it itself — build, tests, tmux-drive, whatever.
  #     This is machine-checked reality, not an LLM's claim, so it cannot be faked.
  #     A non-zero exit auto-FAILS the round and feeds the REAL output back to the
  #     coder — no LLM needed to catch a broken build/test. Only diffs that pass
  #     the deterministic gate even reach the council. Set VERIFY_CMD to a script
  #     that ends in the behavioral check (e.g. make + go test + a tmux-drive that
  #     greps the rendered pane). Empty VERIFY_CMD = skip (LLM-judgment only).
  if [ -n "${VERIFY_CMD:-}" ]; then
    # E2-hardening: the gate must be UNFAKEABLE. E2 proved a coder can poison an
    # in-repo gate (a fake pytest.py / conftest.py / sitecustomize.py that exits 0).
    # Two defenses, on the FIRST round only (warn once):
    #  (1) WARN if VERIFY_CMD references an in-repo test path — that gate is fakeable
    #      (the coder can edit it). The gate should point at a HELD-OUT artifact.
    #  (2) Run the gate from a CLEAN cwd with a scrubbed PYTHONPATH so a poisoned
    #      file sitting in $REPO (sitecustomize/conftest/pytest shim) is not on the
    #      import path. The operator's VERIFY_CMD `cd`s into the repo itself when it
    #      legitimately needs to (e.g. `cd repo && go test`); we just don't START there.
    if [ "$round" -eq 1 ]; then
      case "$VERIFY_CMD" in
        *test_*|*/tests/*|*pytest*|*conftest*)
          echo "  ⚠ E2-WARNING: VERIFY_CMD references an in-repo test path — if the coder can edit it, the gate is FAKEABLE (E2). Prefer a held-out grader outside \$REPO." >&2 ;;
      esac
    fi
    echo "-- deterministic gate: running VERIFY_CMD (clean cwd, scrubbed env) --"
    if ( cd / && env -u PYTHONPATH -u PYTHONSTARTUP bash -c "$VERIFY_CMD" ) > "$RUN_DIR/verify-$round.log" 2>&1; then
      echo "  ✓ VERIFY_CMD passed (build/test/behavioral check green)"
    else
      echo "  ✗ VERIFY_CMD FAILED (exit $?) — auto-rejecting, feeding real output to coder"
      {
        echo "VERDICT: FAIL"
        echo "REASON: the deterministic verification command failed — this is machine-checked reality, not opinion. Fix it."
        echo "CHANGES_REQUIRED:"
        echo "- VERIFY_CMD ($VERIFY_CMD) exited non-zero. Its output (last 40 lines):"
        tail -40 "$RUN_DIR/verify-$round.log" | sed 's/^/    /'
      } > "$RUN_DIR/verdict.txt"
      cat "$RUN_DIR/verdict.txt"
      echo "-- deterministic gate rejected; looping (no LLM call this round) --"
      continue   # skip the council entirely — a broken build is not a judgment call
    fi
  fi

  # 3) REVIEW the diff. Two modes:
  #    - default: ONE reviewer, strict binary verdict (cheap, fast).
  #    - COUNCIL=1: a council of independent specialist VOICES judge in parallel
  #      (karpathy/llm-council Stage 1), then a chairman synthesizes one verdict
  #      (Stage 3). Each voice is blind to the others — diverse lenses catch what
  #      a single reviewer misses (the multi-voice decision standard).
  DIFF_FILE="$RUN_DIR/round-$round.diff"
  if [ "${COUNCIL:-0}" = "1" ]; then
    echo "-- COUNCIL reviewing ($REVIEWER_MODEL): correctness · simplicity · security --"
    # Stage 1: independent specialist voices, each a fresh context, run in parallel.
    council_voice() {
      local name="$1" lens="$2"
      cat > "$RUN_DIR/voice-$name.prompt" <<EOF
You are the $name reviewer on a code-review council. Judge ONLY this lens:
$lens

You see the diff in isolation; other reviewers cover other lenses — do NOT pass
something just because it's "probably fine elsewhere". Be strict on YOUR lens.

TASK: $TASK
--- DIFF ---
$(cat "$DIFF_FILE")
--- END DIFF ---

Reply in EXACTLY this format:
VOICE: $name
VERDICT: PASS  (or)  FAIL
FINDINGS:
- <each concrete issue on your lens; omit if PASS>
EOF
      run_claude "$REVIEWER_MODEL" "voice-$name" "$RUN_DIR/voice-$name.prompt" \
          --permission-mode plan > "$RUN_DIR/voice-$name.txt" 2>/dev/null
    }
    council_voice correctness "Does it fully satisfy the task? Correct logic, real edge/error cases handled, tests actually cover the behavior (happy + failure paths)?" &
    council_voice simplicity  "DHH/simplicity bar: simplest design that works? Over-engineering, speculative abstraction, dead code, poor naming, style mismatch with the repo?" &
    council_voice security    "Security + data integrity: input validation, injection, secrets in code, unsafe ops, least privilege, destructive actions without guards?" &
    wait
    # Stage 3: chairman synthesizes the voices into one verdict. PASS only if every
    # voice passed (a single FAIL on any lens fails the diff — strict by design).
    cat > "$RUN_DIR/chair.prompt" <<EOF
You are the CHAIRMAN of a code-review council. Three independent reviewers judged
this diff on separate lenses. Synthesize their findings into ONE verdict.

RULE: the diff PASSES only if ALL three voices passed. If ANY voice found a real
issue, the verdict is FAIL and you consolidate every concrete finding into a
deduplicated, actionable change list for the coder.

--- CORRECTNESS VOICE ---
$(cat "$RUN_DIR/voice-correctness.txt" 2>/dev/null)
--- SIMPLICITY VOICE ---
$(cat "$RUN_DIR/voice-simplicity.txt" 2>/dev/null)
--- SECURITY VOICE ---
$(cat "$RUN_DIR/voice-security.txt" 2>/dev/null)
--- END ---

Reply in EXACTLY this format and nothing else:
VERDICT: PASS  (or)  FAIL
REASON: <one line synthesis>
CHANGES_REQUIRED:
- <consolidated bullet>   (omit this section entirely if PASS)
EOF
    run_claude "$REVIEWER_MODEL" chair "$RUN_DIR/chair.prompt" \
        --permission-mode plan > "$RUN_DIR/verdict.txt"
    echo "  voices: correctness=$(grep -m1 '^VERDICT:' "$RUN_DIR/voice-correctness.txt" 2>/dev/null | awk '{print $2}') simplicity=$(grep -m1 '^VERDICT:' "$RUN_DIR/voice-simplicity.txt" 2>/dev/null | awk '{print $2}') security=$(grep -m1 '^VERDICT:' "$RUN_DIR/voice-security.txt" 2>/dev/null | awk '{print $2}')"
  else
    cat > "$RUN_DIR/reviewer.prompt" <<EOF
You are the REVIEWER (independent of the coder). Review ONLY this staged diff for
correctness, simplicity, security, edge cases, tests, and whether it fully
satisfies the task:

TASK: $TASK

--- DIFF ---
$(cat "$DIFF_FILE")
--- END DIFF ---

Respond in EXACTLY this format and nothing else:
VERDICT: PASS    (or)    VERDICT: FAIL
REASON: <one line>
CHANGES_REQUIRED:
- <bullet>   (omit this section entirely if PASS)
EOF
    echo "-- reviewer judging ($REVIEWER_MODEL) --"
    run_claude "$REVIEWER_MODEL" reviewer "$RUN_DIR/reviewer.prompt" \
        --permission-mode plan > "$RUN_DIR/verdict.txt"
  fi
  cat "$RUN_DIR/verdict.txt"

  # 4) Gate decision.
  if grep -qE '^VERDICT:[[:space:]]*PASS' "$RUN_DIR/verdict.txt"; then
    echo "===== REVIEWER PASSED on round $round — lifting the gate ====="
    # SINGLE-THREADED WRITE: only the driver commits, only after a PASS.
    git commit -m "feat: $TASK

Reviewed-by: $([ "${COUNCIL:-0}" = "1" ] && echo "review-council (correctness/simplicity/security)" || echo "reviewer-agent") ($REVIEWER_MODEL), round $round
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" >/dev/null 2>&1 \
      && echo "committed." || echo "(commit skipped — resolve manually)"
    echo "artifacts in $RUN_DIR"
    exit 0
  fi
  echo "-- reviewer requested changes; looping --"
done

echo "!! MAX_ROUNDS ($MAX_ROUNDS) reached without a PASS — STOP for human gate." >&2
echo "   last verdict: $RUN_DIR/verdict.txt ; last diff: $RUN_DIR/round-$round.diff" >&2
exit 4
