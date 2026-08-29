# Plan 004: Integrate held-out gate with VERIFY_CMD

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- lib/heldout-gate.sh review-loop.sh gstack-review.sh README.md tests/`
> On mismatch with excerpts, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/002-orchestration-test-harness-ci.md
- **Category**: security
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

README documents `lib/heldout-gate.sh` as the C0 defense against fakeable in-repo
verifiers (E2 red-team: poisoned pytest shims). `VERIFY_CMD` in `review-loop.sh`
and `gstack-review.sh` only scrubs `PYTHONPATH` and runs from `cd /` — it does
NOT run `heldout_preflight` or require graders outside the work tree. Operators
can still point `VERIFY_CMD` at in-repo scripts the coder can edit. The held-out
gate library exists and is CI-tested in isolation but is not wired into the loops
operators actually use.

## Current state

- `lib/heldout-gate.sh` — `heldout_gate <work_dir> <grader_path>` with preflight,
  clean cwd execution, SCORE parsing (lines 101–149).
- CI already validates heldout contract inline (`.github/workflows/ci.yml` lines 28–42).
- `review-loop.sh` VERIFY_CMD block (lines 244–275): runs
  `( cd / && env -u PYTHONPATH ... bash -c "$VERIFY_CMD" )` — no heldout integration.
- `gstack-review.sh` VERIFY_CMD block (lines 168–177): same pattern.
- README held-out section (lines 166–175) shows direct `heldout_gate` usage but not
  loop integration.

Design constraint from CONTRIBUTING principle 6: fail loudly, never silent
degradation.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Heldout CI contract | see `.github/workflows/ci.yml` inline test | OK: heldout-gate contract |
| Orchestration tests | `bash tests/run-orchestration-tests.sh` | exit 0 |
| Selftests | `bash planner.sh --selftest && bash gstack-loop.sh --selftest` | proven |
| shellcheck | `shellcheck -S warning lib/heldout-gate.sh review-loop.sh gstack-review.sh` | exit 0 |

## Scope

**In scope**:
- `review-loop.sh` — VERIFY_CMD integration
- `gstack-review.sh` — VERIFY_CMD integration
- `tests/test-heldout-verify.sh` (new)
- `tests/run-orchestration-tests.sh` — register new test
- `README.md` — document `HELDOUT_GRADER` env var (verification table only)

**Out of scope**:
- Rewriting `lib/heldout-gate.sh` core logic (unless preflight bug found)
- Mandatory held-out gate when `VERIFY_CMD` unset (still LLM-only mode)
- Vendored skills

## Git workflow

- Branch: `advisor/004-heldout-verify-cmd`
- Commit: `feat: wire held-out gate into VERIFY_CMD paths`
- Do NOT push unless instructed.

## Steps

### Step 1: Define operator-facing env contract

Add optional env vars (both loops):

| Var | Meaning |
|-----|---------|
| `HELDOUT_GRADER` | Absolute path to executable grader OUTSIDE `$REPO` |
| `GATE_MIN_SCORE` | Passed through to heldout_gate (default 1.0) |
| `GATE_BASELINE` | Optional ratchet baseline |
| `GATE_PIN_SHA` | Optional grader sha256 pin |

Behavior when `VERIFY_CMD` is set:

1. If `HELDOUT_GRADER` is set → call `heldout_gate "$REPO" "$HELDOUT_GRADER"` first.
   - Exit 0 → proceed (optional: still run VERIFY_CMD as secondary check — see below)
   - Exit 1 → FAIL verdict (grader failed)
   - Exit 2 → FATAL: structural C0 violation; exit loop with distinct code (e.g. 6)

2. If `HELDOUT_GRADER` unset → keep current VERIFY_CMD behavior BUT strengthen
   round-1 warning to stderr: "VERIFY_CMD without HELDOUT_GRADER is fakeable".

Recommended: when `HELDOUT_GRADER` set, treat heldout_gate as primary gate;
run VERIFY_CMD only if ALSO set (both must pass). Document in README.

Source heldout lib at top of both scripts:

```bash
. "$SCRIPT_DIR/lib/heldout-gate.sh"
```

**Verify**: `bash -n review-loop.sh gstack-review.sh` → exit 0.

### Step 2: Implement shared helper

Add a small function in each script (or extract to `lib/verify-gate.sh` if you
prefer one copy — either is fine, prefer DRY):

```bash
run_verify_gate() {
  local round="$1" run_dir="$2" repo="$3"
  # heldout path if HELDOUT_GRADER set
  # then VERIFY_CMD if set
  # write verify-$round.log and verdict.txt on failure matching existing format
}
```

Preserve existing verdict.txt shape so coder feedback loops unchanged.

**Verify**: manual temp-dir test in Step 4.

### Step 3: Update README env table

Add rows for `HELDOUT_GRADER`, `GATE_MIN_SCORE`, `GATE_BASELINE`, `GATE_PIN_SHA`
with one-line meanings. Add example:

```bash
HELDOUT_GRADER=/opt/graders/my-task.sh VERIFY_CMD='cd repo && npm test' \
  ./review-loop.sh "task" ./repo
```

**Verify**: `grep HELDOUT_GRADER README.md` shows table entry.

### Step 4: Add `tests/test-heldout-verify.sh`

Reuse CI's temp-dir pattern:

1. Create `$tmp/work` and `$tmp/outside/good.sh` (SCORE: 1.0) and `$tmp/work/inside.sh`.
2. Source `lib/heldout-gate.sh`; assert rc 0/2/1 for good/inside/bad graders.
3. If helper function lives in a lib file, test via minimal bash snippet that
   sets `HELDOUT_GRADER` and mocks repo path — no need to spawn review-loop fully.

Add to orchestration harness.

**Verify**: `bash tests/test-heldout-verify.sh` → exit 0.

## Test plan

- Offline temp-dir tests only (mirror CI heldout contract).
- Do not require real grader projects on disk outside tmp.

**Verify**: `bash tests/run-orchestration-tests.sh` → exit 0.

## Done criteria

- [ ] Both loops source `lib/heldout-gate.sh` and honor `HELDOUT_GRADER`
- [ ] Structural C0 violation exits with distinct non-zero code (document in header)
- [ ] Existing VERIFY_CMD behavior preserved when `HELDOUT_GRADER` unset
- [ ] README documents new env vars
- [ ] `tests/test-heldout-verify.sh` in harness
- [ ] `shellcheck -S warning` clean on touched scripts
- [ ] `plans/README.md` row 004 updated

## STOP conditions

- `heldout_gate` signature changed from `(work_dir, grader_path, ...)` — reconcile.
- Integrating heldout breaks existing VERIFY_CMD-only users with no migration path —
  STOP and propose compat flag.
- Cannot source heldout-gate without side effects when run as library — fix first.

## Maintenance notes

- Operators should place graders outside repo clone; document in README.
- If VERIFY_CMD and HELDOUT_GRADER disagree, both failing is intentional defense-in-depth.
