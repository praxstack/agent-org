# Plan 001: Wire commit gate into gstack-review coder

> **Executor instructions**: Follow this plan step by step. Run every verification
> command and confirm the expected result before moving to the next step. If anything
> in the "STOP conditions" section occurs, stop and report — do not improvise. When
> done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- gstack-review.sh lib/runner.sh review-loop.sh`
> If any in-scope file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug | security
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

`gstack-review.sh` is the heterogeneous review council used by the gstack outer loop.
It creates `coder-settings.json` with the `block-commit.sh` PreToolUse hook, and its
prompts tell the coder that commits are blocked. But the coder invocation never passes
those settings to Claude, so the hook never runs. The core agent-org invariant — coder
produces a diff and cannot self-commit — is broken on this path. `review-loop.sh` already
wires `--settings` correctly; gstack-review must match.

## Current state

- `gstack-review.sh` — heterogeneous review loop; creates settings but does not use them.
- `lib/runner.sh` — `run_agent` dispatches to claude/hermes/pi/codex/opencode; claude branch
  has no `--settings` parameter.
- `review-loop.sh` — reference implementation: `run_claude` passes `--settings "$CODER_SETTINGS"`.
- `hooks/block-commit.sh` — PreToolUse hook; exit 2 blocks `git commit` / `git push`.

Excerpt — settings created but unused (`gstack-review.sh`):

```bash
CODER_SETTINGS="$RUN_DIR/coder-settings.json"
cat > "$CODER_SETTINGS" <<JSON
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "$HOOK" } ] } ] } }
JSON
# ...
run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out"   # no settings passed
```

Excerpt — working pattern (`review-loop.sh`):

```bash
run_claude "$CODER_MODEL" coder "$RUN_DIR/coder.prompt" \
    --settings "$CODER_SETTINGS" > "$RUN_DIR/coder.reply.txt"
```

Excerpt — claude branch in `lib/runner.sh` (no settings today):

```bash
"$CLAUDE_BIN" -p "$prompt" --model "${model:-$token}" --output-format json \
    --permission-mode plan > "$out.raw" 2>"$out.err" || true
```

Design constraint from `gstack-review.sh` header: **SINGLE-THREADED WRITE** — only the
driver commits. The hook is the enforcement mechanism for Claude coders.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Planner selftest | `bash planner.sh --selftest` | 8 passed, exit 0 |
| Gstack loop selftest | `bash gstack-loop.sh --selftest` | 8 passed, exit 0 |
| Shellcheck | `shellcheck -S warning gstack-review.sh lib/runner.sh` | exit 0 |
| Syntax | `bash -n gstack-review.sh && bash -n lib/runner.sh` | exit 0 |
| Hook smoke (existing) | see `.github/workflows/ci.yml` gate-smoke job | commit blocked rc=2 |

## Scope

**In scope**:
- `lib/runner.sh` — add optional settings path for claude invocations
- `gstack-review.sh` — pass settings when coder is a claude token
- `.github/workflows/ci.yml` — add gstack-review settings wiring smoke (or extend gate-smoke)

**Out of scope**:
- Non-claude coders (hermes/pi/codex) — hook is Claude-specific; document that driver-only
  commit invariant still applies via driver not calling `git commit`.
- `review-loop.sh` — already correct; use as reference only.
- `fanout.sh` — separate plan 005.

## Git workflow

- Branch: `advisor/001-wire-gstack-review-commit-gate`
- Commit message style: imperative, e.g. `fix(gstack-review): pass coder settings to claude runner`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Extend `run_agent` to accept optional settings

Add an optional 4th argument `settings_file` to `run_agent`, or add `run_agent_claude`
with settings support. Prefer minimal API change: optional 4th arg, empty = current behavior.

In the `claude:*|*)` branch, when settings file is provided and readable, append
`--settings "$settings_file"` to the claude CLI invocation (match `review-loop.sh`).

**Verify**: `bash -n lib/runner.sh` → exit 0

### Step 2: Pass settings from gstack-review for claude coders

In `gstack-review.sh`, when invoking the coder:

```bash
if [[ "$CODER" == claude* ]] || [[ "$CODER" != *:* ]]; then
  run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out" "$CODER_SETTINGS"
else
  run_agent "$CODER" "$RUN_DIR/coder.prompt" "$RUN_DIR/coder.out"
fi
```

(Adjust detection to match how bare tokens map to claude in `runner_of`.)

**Verify**: `grep -n 'CODER_SETTINGS' gstack-review.sh` shows both creation and pass-through.

### Step 3: Add CI smoke that settings JSON references the hook

Add a job step (gate-smoke or new) that:

1. Runs `bash -c 'source gstack-review.sh logic'` OR sources the settings-generation pattern.
2. Asserts generated `coder-settings.json` contains `block-commit.sh` path.
3. Optionally dry-run: simulate the claude command line includes `--settings`.

Minimal approach: extract settings generation into a testable function or add a
`gstack-review.sh --selftest` case that checks `CODER_SETTINGS` would be passed.

**Verify**: `bash gstack-review.sh --selftest` (if added) → pass; or CI step passes locally.

## Test plan

- Extend or add selftest: after sourcing runner + gstack helpers, assert claude `run_agent`
  command construction includes `--settings` when 4th arg provided.
- Manual: run hook smoke with `git commit` JSON → rc=2 (existing CI).
- Regression: `bash planner.sh --selftest` and `bash gstack-loop.sh --selftest` still pass.

## Done criteria

- [ ] `bash planner.sh --selftest` exits 0
- [ ] `bash gstack-loop.sh --selftest` exits 0
- [ ] `shellcheck -S warning gstack-review.sh lib/runner.sh` exits 0
- [ ] `gstack-review.sh` coder path passes `$CODER_SETTINGS` for claude tokens
- [ ] CI includes a check that gstack-review commit gate is wired (not just review-loop)
- [ ] `plans/README.md` status row for 001 updated to DONE

## STOP conditions

- `run_agent` signature already changed incompatibly on main — reconcile before proceeding.
- Claude CLI in this environment does not support `--settings` — report version/help output.
- Fix requires modifying `review-loop.sh` beyond reference — scope creep; stop and report.

## Maintenance notes

- Any new entry point that spawns a claude coder must pass settings the same way.
- Plan 005 adds broader CI coverage; keep smoke tests in sync with runner API.
- Reviewers should confirm the 4th-arg optional pattern does not break existing 3-arg callers.
