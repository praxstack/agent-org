# Plan 004: Integrate heldout-gate into main review loops

> **Executor instructions**: Follow this plan step by step. Run every verification
> command and confirm the expected result before moving to the next step. If anything
> in the "STOP conditions" section occurs, stop and report — do not improvise. When
> done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- gstack-review.sh review-loop.sh lib/heldout-gate.sh README.md`
> If any in-scope file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-wire-gstack-review-commit-gate.md
- **Category**: security | tests
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

`lib/heldout-gate.sh` implements the C0 "unfakeable" gate: graders must live outside the
work directory so a pressured coder cannot shadow `pytest` with a fake local script.
README documents usage, and CI tests the library contract — but **no main loop calls
`heldout_gate`**. `VERIFY_CMD` in `gstack-review.sh` / `review-loop.sh` runs in-repo
commands and remains gameable. Integrating heldout-gate closes the documented security gap.

## Current state

- `lib/heldout-gate.sh` — `heldout_gate <work_dir> <grader_path> [args...]`; rc 0=PASS,
  1=FAIL, 2=structural violation (grader inside work_dir).
- `gstack-review.sh` — optional `VERIFY_CMD` runs via `bash -c` from `/` with scrubbed env.
- `review-loop.sh` — similar VERIFY_CMD pattern (if present).
- `README.md` — documents heldout gate with example sourcing.
- `.github/workflows/ci.yml` — contract tests for heldout-gate in isolation only.

Grep at audit: `heldout_gate` appears only in `lib/heldout-gate.sh` and CI — not in loops.

Excerpt — gameable VERIFY_CMD (`gstack-review.sh:167-177`):

```bash
if [ -n "${VERIFY_CMD:-}" ]; then
  if ( cd / && env -u PYTHONPATH ... bash -c "$VERIFY_CMD" ) > "$RUN_DIR/verify-$round.log" 2>&1; then
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Heldout contract | CI heldout-gate step (see ci.yml) | OK: heldout-gate contract holds |
| Selftests | `bash planner.sh --selftest && bash gstack-loop.sh --selftest` | exit 0 |
| Integration test | new script or selftest invoking loop with held-out grader | PASS/FAIL paths |

## Scope

**In scope**:
- `gstack-review.sh` — add `HELDOUT_GRADER` env (path outside repo) wired to `heldout_gate`
- `review-loop.sh` — same optional integration (if VERIFY_CMD exists there)
- `README.md` — document env var and precedence vs VERIFY_CMD
- `.github/workflows/ci.yml` — optional integration smoke with temp dirs

**Out of scope**:
- Shipping production graders (operator provides paths).
- Removing VERIFY_CMD (keep for quick local checks; document as weaker).

## Git workflow

- Branch: `advisor/004-integrate-heldout-gate`
- Commit message: `feat(gstack): wire heldout_gate as optional verification primitive`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Source heldout-gate in review loops

At top of `gstack-review.sh` (after other lib sources):

```bash
. "$SCRIPT_DIR/lib/heldout-gate.sh"
```

### Step 2: Add HELDOUT_GRADER env hook

After coder stages diff, before council review (same slot as VERIFY_CMD):

```bash
if [ -n "${HELDOUT_GRADER:-}" ]; then
  echo "-- held-out gate (C0) --"
  if heldout_gate "$REPO" "$HELDOUT_GRADER" > "$RUN_DIR/heldout-$round.txt"; then
    echo "  ✓ heldout_gate passed"
  else
    rc=$?
    # feed verdict.txt like VERIFY_CMD failure path
  fi
fi
```

Precedence: if both `HELDOUT_GRADER` and `VERIFY_CMD` set, run heldout first (stronger),
or document mutual exclusion.

**Verify**: `bash -n gstack-review.sh` → exit 0

### Step 3: Mirror in review-loop.sh (if applicable)

Search `review-loop.sh` for VERIFY_CMD; add parallel HELDOUT_GRADER block using same pattern.

**Verify**: `bash -n review-loop.sh` → exit 0

### Step 4: Document in README

Add subsection under heldout-gate: set `HELDOUT_GRADER=/path/outside/repo/grader.sh` when
invoking `gstack-review.sh` or `review-loop.sh`.

**Verify**: `grep HELDOUT_GRADER README.md` returns usage.

### Step 5: CI integration smoke (optional but recommended)

Add ci step: create temp work dir + outside grader, run a minimal bash -c that sources
gstack-review and calls heldout_gate path only (not full agent run).

## Test plan

- Reuse heldout-gate contract tests (unchanged).
- New: integration test with good/bad graders through gstack-review code path (mocked,
  no real Claude).
- Document HELDOUT_GRADER in plan 005 if CI expanded there.

## Done criteria

- [ ] `heldout_gate` callable from `gstack-review.sh` when `HELDOUT_GRADER` set
- [ ] Failure feeds council/coder same as VERIFY_CMD failure
- [ ] README documents the env var
- [ ] `bash planner.sh --selftest` and `bash gstack-loop.sh --selftest` exit 0
- [ ] `plans/README.md` status row for 004 updated to DONE

## STOP conditions

- `heldout_gate` signature changed — re-read `lib/heldout-gate.sh` header.
- `$REPO` is not absolute and breaks grader path checks — normalize with `cd` + `pwd`.
- Integration requires real agent runs in CI — stop and propose lighter smoke.

## Maintenance notes

- Operators must deploy graders outside any repo the coder can write.
- Future: default grader path in cloud-agent-install or env template.
- Reviewers: ensure failure messages do not leak grader secrets.
