# Plan 002: Harden block-commit against git alias bypass

> **Executor instructions**: Follow this plan step by step. Run every verification
> command and confirm the expected result before moving to the next step. If anything
> in the "STOP conditions" section occurs, stop and report — do not improvise. When
> done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- hooks/block-commit.sh .github/workflows/ci.yml`
> If any in-scope file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

The commit gate hook blocks commands matching `\bgit[[:space:]]+(commit|push)\b`. A coder
agent can bypass this with `git ci` (alias), `git -c alias.ci=commit ci`, or other git
subcommand indirection. Verified at audit time: both alias forms exit 0 (allowed). This
undermines the "coder cannot self-commit" security model even when settings are wired.

## Current state

- `hooks/block-commit.sh` — PreToolUse hook; parses JSON stdin for `tool_input.command`.
- `.github/workflows/ci.yml` — gate-smoke tests direct `git commit` and `git push` only.

Excerpt — current gate (`hooks/block-commit.sh:33-38`):

```bash
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
  echo "GATE: commits are blocked for the coder agent. Do NOT commit." >&2
  # ...
  exit 2
fi
```

Verified bypass (audit, read-only):

```bash
printf '%s' '{"tool_input":{"command":"git ci -m x"}}' | bash hooks/block-commit.sh  # rc=0
printf '%s' '{"tool_input":{"command":"git -c alias.ci=commit ci -m x"}}' | bash hooks/block-commit.sh  # rc=0
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Hook smoke (extended) | run alias cases below | alias blocked rc=2 |
| Shellcheck | `shellcheck -S warning hooks/block-commit.sh` | exit 0 |
| CI parity | mirror `.github/workflows/ci.yml` gate-smoke locally | all OK lines |

## Scope

**In scope**:
- `hooks/block-commit.sh` — broaden detection
- `.github/workflows/ci.yml` — add alias bypass regression cases

**Out of scope**:
- Blocking `git` entirely (coders need `git status`, `git diff`, `git add`).
- Non-git VCS commit paths.
- OS-level sandboxing (future hardening).

## Git workflow

- Branch: `advisor/002-harden-block-commit-alias-bypass`
- Commit message: `fix(hooks): block git commit/push aliases in block-commit`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Expand command detection

After extracting `$cmd`, block if ANY of these hold:

1. Existing: `\bgit[[:space:]]+(commit|push)\b`
2. `git` invocation where first subcommand resolves to commit/push via common aliases
   (`ci`, `cm`, etc.) — use conservative regex for known alias names OR parse `git` argv.
3. `git -c alias.<name>=commit` style inline alias definitions followed by that alias name.

Pragmatic approach: block `\bgit\b` commands whose first non-flag token (after global
options like `-C`, `-c`) is `commit`, `push`, or matches a small denylist of common
commit aliases (`ci`, `cm`, `publish` if used for push).

Also block: `git -c alias.X=commit X` by detecting `-c alias.*=commit` or `-c alias.*=push`.

**Verify**:

```bash
printf '%s' '{"tool_input":{"command":"git ci -m x"}}' | bash hooks/block-commit.sh; echo rc=$?
# expect rc=2
printf '%s' '{"tool_input":{"command":"git -c alias.ci=commit ci -m x"}}' | bash hooks/block-commit.sh; echo rc=$?
# expect rc=2
printf '%s' '{"tool_input":{"command":"git status"}}' | bash hooks/block-commit.sh; echo rc=$?
# expect rc=0
printf '%s' '{"tool_input":{"command":"pytest -q"}}' | bash hooks/block-commit.sh; echo rc=$?
# expect rc=0
```

### Step 2: Extend CI gate-smoke

In `.github/workflows/ci.yml` gate-smoke job, add the two alias cases above with
`[ "$rc" -eq 2 ]` assertions, matching existing commit/push tests.

**Verify**: `bash -n .github/workflows/ci.yml` is not applicable; YAML valid by inspection;
run the shell snippet locally.

## Test plan

- CI gate-smoke: direct commit, push, alias ci, inline alias, safe pytest — 5 cases.
- Optional: add `hooks/block-commit.sh --selftest` if the repo pattern supports it.

## Done criteria

- [ ] Alias bypass cases return exit 2
- [ ] `git status`, `git add`, `git diff` still return exit 0
- [ ] `shellcheck -S warning hooks/block-commit.sh` exits 0
- [ ] CI gate-smoke includes alias regression cases
- [ ] `plans/README.md` status row for 002 updated to DONE

## STOP conditions

- Broadened regex blocks `git add` or test commands — narrow the pattern.
- jq-less fallback path breaks — test both jq and grep extraction paths.
- Git introduces new syntax not covered — document limitation in hook header comment.

## Maintenance notes

- Perfect git alias resolution requires running `git config`; optional enhancement if
  regex approach proves insufficient.
- Plan 001 must wire settings before this hook matters on gstack-review path.
- Reviewers: scrutinize false positives on legitimate `git` workflows.
