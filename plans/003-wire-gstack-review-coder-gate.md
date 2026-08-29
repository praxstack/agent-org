# Plan 003: Wire gstack-review coder gate and edit permissions

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- gstack-review.sh lib/runner.sh hooks/block-commit.sh tests/`
> Compare "Current state" excerpts on mismatch; STOP if assumptions fail.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-harden-block-commit-hook.md, plans/002-orchestration-test-harness-ci.md
- **Category**: security
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

`gstack-review.sh` creates `CODER_SETTINGS` with the commit-block hook but never
passes it to the coder. The coder is invoked via `run_agent` in `lib/runner.sh`,
which always uses `--permission-mode plan` for Claude — read-only/plan mode, not
edit mode. Result: the script claims a gated coder that can implement and stage
changes, but Claude coders neither receive the PreToolUse hook nor (likely) edit
permissions. This breaks the inner loop and violates single-threaded write
discipline if a coder can commit through an unhooked path.

## Current state

- `gstack-review.sh` builds settings (lines 59–64) but coder call omits them (line 155):

```59:64:gstack-review.sh
CODER_SETTINGS="$RUN_DIR/coder-settings.json"
cat > "$CODER_SETTINGS" <<JSON
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "$HOOK" } ] } ] } }
JSON
```

```154:155:gstack-review.sh
    echo "-- coder ($CODER) --"
    run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out"
```

- `lib/runner.sh` Claude path (lines 80–82):

```80:82:lib/runner.sh
    claude:*|*)
      "$CLAUDE_BIN" -p "$prompt" --model "${model:-$token}" --output-format json \
          --permission-mode plan > "$out.raw" 2>"$out.err" || true
```

- `review-loop.sh` pattern to match for coders (lines 95–100, 192–194):
  - Uses `PERM_ARGS=(--permission-mode acceptEdits)` or `YOLO=1` →
    `--dangerously-skip-permissions`
  - Passes `--settings "$CODER_SETTINGS"` to coder invocations only
  - Reviewers use `--permission-mode plan`

- Non-Claude coders (hermes, codex, pi): no PreToolUse hook exists; defense is
  driver-only commits — document this limitation in comments.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Syntax | `bash -n lib/runner.sh gstack-review.sh` | exit 0 |
| Orchestration tests | `bash tests/run-orchestration-tests.sh` | exit 0 |
| shellcheck | `shellcheck -S warning lib/runner.sh gstack-review.sh` | exit 0 |
| Selftests | `bash planner.sh --selftest && bash gstack-loop.sh --selftest` | proven |

## Scope

**In scope**:
- `lib/runner.sh` — extend `run_agent` API
- `gstack-review.sh` — pass settings + mode to coder
- `tests/test-runner.sh` (new) or extend `tests/run-orchestration-tests.sh`

**Out of scope**:
- `review-loop.sh` (already correct; use as reference only)
- Non-Claude commit hooks for hermes/codex (no API — document only)
- `fanout.sh`, `planner.sh` reviewer/plan paths (stay on `plan` mode)

## Git workflow

- Branch: `advisor/003-gstack-review-coder-gate`
- Commit message: `fix(gstack-review): wire commit gate and edit mode for coders`
- Do NOT push unless instructed.

## Steps

### Step 1: Extend `run_agent` signature

Change `run_agent` to accept optional 4th+ args via env vars (bash 3.2 friendly)
OR explicit optional parameters:

Preferred env-based API (document in header comment):

```bash
# RUN_AGENT_MODE=plan|edit|yolo  (default plan — reviewers)
# RUN_AGENT_SETTINGS=/path/to/settings.json  (optional, claude only)
run_agent <token> <prompt-file> <out-file>
```

Behavior:
- `RUN_AGENT_MODE=edit` → Claude uses `--permission-mode acceptEdits`
- `RUN_AGENT_MODE=yolo` → Claude uses `--dangerously-skip-permissions`
- `RUN_AGENT_MODE=plan` or unset → `--permission-mode plan` (current behavior)
- When `RUN_AGENT_SETTINGS` is set and runner is claude, append
  `--settings "$RUN_AGENT_SETTINGS"` to the CLI invocation
- Reviewer call sites unchanged if they don't set env vars

Match `review-loop.sh` empty-array idiom if passing optional args arrays.

**Verify**: `bash -n lib/runner.sh` → exit 0.

### Step 2: Wire gstack-review coder invocation

Before `run_agent "$CODER" ...` on line ~155:

```bash
export RUN_AGENT_MODE="${CODER_MODE:-yolo}"   # default yolo for headless like review-loop YOLO=1
export RUN_AGENT_SETTINGS="$CODER_SETTINGS"
run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out"
unset RUN_AGENT_MODE RUN_AGENT_SETTINGS
```

Support env overrides documented in header comment:
- `CODER_MODE=edit` for stricter environments
- `YOLO=0` maps to `edit` if you prefer parity with review-loop naming

Add comment: non-Claude coders ignore `RUN_AGENT_SETTINGS`; driver still sole committer.

**Verify**: `bash -n gstack-review.sh` → exit 0.

### Step 3: Add offline test `tests/test-runner.sh`

Without calling real `claude`, test the wiring by:

1. Creating a stub `CLAUDE_BIN` script in temp dir that echoes its argv to a file.
2. Setting `CLAUDE_BIN` to that stub.
3. Calling `run_agent claude:sonnet prompt out` with:
   - `RUN_AGENT_MODE=edit` and `RUN_AGENT_SETTINGS=/tmp/settings.json`
4. Assert stub output contains `--permission-mode acceptEdits` and
   `--settings /tmp/settings.json`.

5. Repeat with unset env → assert `--permission-mode plan` and no settings flag.

Add to `tests/run-orchestration-tests.sh`.

**Verify**: `bash tests/test-runner.sh` → exit 0.

### Step 4: Document env vars in `gstack-review.sh` header

Add to Env section:

```
CODER_MODE   edit|yolo (default yolo) — claude permission mode for implementer
YOLO         alias: if YOLO=0, use edit mode
```

**Verify**: `grep CODER_MODE gstack-review.sh` shows header + usage.

## Test plan

- `tests/test-runner.sh` stub-binary approach (no network).
- Full end-to-end with real `claude` is manual per CONTRIBUTING — not required for done criteria.

**Verify**: `bash tests/run-orchestration-tests.sh` → exit 0.

## Done criteria

- [ ] `run_agent` honors `RUN_AGENT_MODE` and `RUN_AGENT_SETTINGS` for Claude
- [ ] `gstack-review.sh` passes commit-gate settings to coder invocations
- [ ] Default coder mode is headless-safe (`yolo` or documented equivalent)
- [ ] Reviewer `run_agent` calls still use plan mode (unchanged behavior)
- [ ] `tests/test-runner.sh` passes in harness
- [ ] `shellcheck -S warning lib/runner.sh gstack-review.sh` exits 0
- [ ] `plans/README.md` row 003 updated

## STOP conditions

- Claude CLI removed `--settings` or `--permission-mode` flags (check `claude --help`).
- `run_agent` signature already changed in drifted code — reconcile before editing.
- Stub test shows settings path not passed — do not mark done until fixed.

## Maintenance notes

- Plan 001 hardens the hook this plan relies on — merge 001 first when possible.
- Future: unify `run_claude` in `review-loop.sh` with `run_agent` to one module.
