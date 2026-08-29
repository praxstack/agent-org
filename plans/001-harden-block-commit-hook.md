# Plan 001: Harden commit-block PreToolUse hook

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- hooks/block-commit.sh .github/workflows/ci.yml`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

The commit gate is the core safety property of agent-org: coders must not commit
until a reviewer passes the diff. `hooks/block-commit.sh` only blocks commands
matching `\bgit[[:space:]]+(commit|push)\b`. A coder can bypass the gate with
`git -C /path commit` or `git -C /path push` because `commit`/`push` are not
immediately after `git`. That defeats single-threaded writes and lets an agent
self-commit without review.

## Current state

- `hooks/block-commit.sh` — PreToolUse hook; exit 2 blocks, exit 0 allows.
- Blocking logic (lines 31–38):

```31:38:hooks/block-commit.sh
# Gate condition: block commits and pushes. The coder must hand the
# reviewer instead of self-committing.
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
  echo "GATE: commits are blocked for the coder agent. Do NOT commit." >&2
  ...
  exit 2
fi
```

- CI smoke test (`.github/workflows/ci.yml` lines 72–81) only checks
  `git commit -m x`, `git push origin main`, and `pytest -q`.

- Verified bypass (run before editing):

```bash
printf '%s' '{"tool_input":{"command":"git -C /tmp commit -m x"}}' | bash hooks/block-commit.sh; echo $?
# prints exit:0 (ALLOWED — bug)
```

- Repo conventions: bash 3.2 portable, `set -uo pipefail`, comments explain the
  PreToolUse contract. Match the existing stderr messaging style.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Syntax | `bash -n hooks/block-commit.sh` | exit 0 |
| Hook smoke (existing) | see Step 3 | all OK lines |
| CI selftests | `bash planner.sh --selftest && bash gstack-loop.sh --selftest` | GATE/SCHEDULER PROVEN |
| shellcheck | `shellcheck -S warning hooks/block-commit.sh` | exit 0 |

## Scope

**In scope**:
- `hooks/block-commit.sh`
- `.github/workflows/ci.yml` (extend gate-smoke job only)

**Out of scope**:
- `review-loop.sh`, `gstack-review.sh`, `lib/runner.sh` (Plan 003 wires settings)
- Blocking `git tag`, `git am`, or non-git VCS commands
- Vendored skills directories

## Git workflow

- Branch: `advisor/001-harden-block-commit-hook`
- Commit message style: imperative, matches repo — e.g. `fix(hooks): block git -C commit/push bypass`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Replace the gate regex with path-agnostic detection

In `hooks/block-commit.sh`, replace the single grep with logic that blocks any
bash command containing a `git` invocation whose next significant token (after
optional global flags like `-C`, `--git-dir`, `-c key=value`) is `commit` or
`push`.

Recommended approach (adapt to match file style):

1. Normalize the command string (already in `$cmd`).
2. Use a bash loop or repeated `sed` to strip leading `git` global options.
3. After normalization, match `^\s*git\s+(commit|push)\b` OR anywhere in a
   chained command (`;`, `&&`, `||`) a segment that normalizes to git commit/push.

Also block common aliases if detectable: if the command is exactly
`commit`/`push` as first word after env assignments, skip (out of scope unless
trivial).

At minimum, these must block (exit 2):
- `git commit -m x`
- `git push origin main`
- `git -C /tmp commit -m x`
- `git -C /tmp push origin main`
- `git --git-dir=/tmp/.git commit -m x`

These must allow (exit 0):
- `pytest -q`
- `git status`
- `git diff`
- `git add -A`

**Verify**: run the matrix in Step 3 manually → blocked cases exit 2, allowed exit 0.

### Step 2: Extend CI gate-smoke job

In `.github/workflows/ci.yml`, under the `gate-smoke` job, add checks for
`git -C /tmp commit` and `git -C /tmp push` expecting exit 2, mirroring the
existing pattern for direct commit/push.

**Verify**: `bash -n .github/workflows/ci.yml` is N/A; re-read the YAML block for
copy-paste errors. Full CI runs on push.

### Step 3: Local regression matrix

Run:

```bash
cd /path/to/agent-org
block() { rc=0; printf '%s' "$1" | bash hooks/block-commit.sh || rc=$?; echo "$2 rc=$rc"; }
block '{"tool_input":{"command":"git commit -m x"}}' "direct commit"
block '{"tool_input":{"command":"git push origin main"}}' "direct push"
block '{"tool_input":{"command":"git -C /tmp commit -m x"}}' "git -C commit"
block '{"tool_input":{"command":"git -C /tmp push origin main"}}' "git -C push"
block '{"tool_input":{"command":"pytest -q"}}' "pytest"
block '{"tool_input":{"command":"git status"}}' "git status"
```

Expected: first four `rc=2`, last two `rc=0`.

## Test plan

- Add the six-case matrix above to CI (or to `tests/hooks-block-commit.sh` if
  Plan 002 created that directory — if not, inline in workflow is fine for this plan).
- Pattern: mirror `.github/workflows/ci.yml` existing gate-smoke step.

**Verify**: `shellcheck -S warning hooks/block-commit.sh` → exit 0.

## Done criteria

- [ ] `bash -n hooks/block-commit.sh` exits 0
- [ ] `git -C /tmp commit` and `git -C /tmp push` are blocked (exit 2)
- [ ] `pytest -q` and `git status` remain allowed (exit 0)
- [ ] CI gate-smoke workflow includes the new cases
- [ ] `shellcheck -S warning hooks/block-commit.sh` exits 0
- [ ] No files outside scope modified
- [ ] `plans/README.md` status row for 001 updated

## STOP conditions

- The hook file structure changed substantially (no `cmd` extraction from JSON).
- A proposed fix blocks `git add`, `git diff`, or `git status` in the matrix.
- Claude Code PreToolUse JSON shape changed (no `.tool_input.command` field).

## Maintenance notes

- Plan 003 will pass `--settings` pointing at this hook for `run_agent` coders;
  keep stderr messages stable so agents still understand the gate.
- Reviewers should scrutinize chained-command parsing for false positives on
  strings like `echo git commit` inside quoted arguments.
