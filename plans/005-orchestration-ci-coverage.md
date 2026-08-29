# Plan 005: Close orchestration CI coverage gaps

> **Executor instructions**: Follow this plan step by step. Run every verification
> command and confirm the expected result before moving to the next step. If anything
> in the "STOP conditions" section occurs, stop and report — do not improvise. When
> done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- fanout.sh lib/ledger.sh .github/workflows/ci.yml gstack-review.sh`
> If any in-scope file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/001-wire-gstack-review-commit-gate.md, plans/002-harden-block-commit-alias-bypass.md
- **Category**: tests | dx
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

Core orchestration pieces lack mechanical safety nets. CI runs selftests for `planner.sh`
and `gstack-loop.sh`, heldout-gate contract, verdict normalizer, bash -n, and review-loop
hook smoke — but `fanout.sh` has no selftest and is not in CI, `lib/ledger.sh` replay has
no dedicated test, and gstack-review commit-gate wiring has no CI assertion. Refactors to
these paths can silently regress behavior that the README promises.

## Current state

- `.github/workflows/ci.yml` — jobs: shellcheck, selftests (planner, gstack-loop,
  heldout-gate, verdict, bash -n), gate-smoke (review-loop hook only).
- `fanout.sh` — multi-model fan-out; documented in README; no `--selftest`.
- `lib/ledger.sh` — append-only ledger; `ledger_replay_verdict` for deterministic replay.
- `gstack-review.sh` — no `--selftest` flag (unlike planner and gstack-loop).

Files in CI bash -n list: `*.sh lib/*.sh hooks/*.sh examples/*.sh scripts/*.sh` — fanout
is syntax-checked but not behavior-tested.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Planner | `bash planner.sh --selftest` | 8 passed |
| Gstack loop | `bash gstack-loop.sh --selftest` | 8+ passed |
| Shellcheck | `shellcheck -S warning fanout.sh lib/ledger.sh` | exit 0 |
| CI local | run ci.yml steps manually | all OK |

## Scope

**In scope**:
- `fanout.sh` — add `--selftest` (mock runners or fixture outputs)
- `lib/ledger.sh` — add testable replay case (in fanout selftest or ci step)
- `.github/workflows/ci.yml` — wire new tests + gstack-review gate smoke (if not in 001)
- `gstack-review.sh` — minimal `--selftest` for settings wiring (may overlap plan 001)

**Out of scope**:
- Full E2E agent runs in CI (too slow/flaky).
- Unifying `fanout.sh` with `lib/runner.sh` (tech debt deferral).
- Testing vendored skills install scripts beyond bash -n.

## Git workflow

- Branch: `advisor/005-orchestration-ci-coverage`
- Commit message: `test: add fanout selftest and ledger replay CI coverage`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add fanout.sh --selftest

Follow pattern from `planner.sh --selftest` / `gstack-loop.sh --selftest`:

- Create temp dir with minimal `roles.toml` and prompt file.
- Mock `run_agent` or use env override if fanout supports it; otherwise stub hermes/claude
  with shell functions that write fixed verdict files.
- Assert ledger file created and `ledger_replay_verdict` matches aggregate expectation.
- Print pass/fail summary; exit 1 on any failure.

**Verify**: `bash fanout.sh --selftest` → exit 0, at least 3 cases

### Step 2: Add ledger replay CI step

In `.github/workflows/ci.yml` selftests job:

```bash
. lib/ledger.sh
# append synthetic events, replay, assert verdict token
```

Or delegate to `bash fanout.sh --selftest` if it covers replay.

**Verify**: run step locally → "OK: ledger replay"

### Step 3: gstack-review --selftest (settings wiring)

If not completed in plan 001, add:

```bash
gstack-review.sh --selftest
```

Cases: CODER_SETTINGS JSON contains hook path; claude coder invocation would include
`--settings` (inspect via dry-run or function export).

**Verify**: `bash gstack-review.sh --selftest` → exit 0

### Step 4: Register in CI

Add workflow steps:

```yaml
- name: fanout selftest
  run: bash fanout.sh --selftest
- name: gstack-review selftest
  run: bash gstack-review.sh --selftest
```

**Verify**: full local reproduction of selftests job passes.

## Test plan

- fanout selftest: spawn 2 roles, one FAIL leaf tolerated, aggregate FAIL.
- ledger replay: deterministic from jsonl alone.
- gstack-review selftest: settings file + runner args (no live claude).
- Regression: all existing CI steps still pass.

## Done criteria

- [ ] `bash fanout.sh --selftest` exits 0
- [ ] CI runs fanout selftest on every PR
- [ ] Ledger replay covered by selftest or dedicated CI step
- [ ] gstack-review commit-gate wiring covered by selftest or CI
- [ ] `bash planner.sh --selftest` and `bash gstack-loop.sh --selftest` still exit 0
- [ ] `plans/README.md` status row for 005 updated to DONE

## STOP conditions

- fanout.sh cannot be tested without live CLIs and no mock seam exists — add `FANOUT_MOCK=1`
  hook first, then test.
- ledger format changed — update replay test fixtures.
- CI job timeout — reduce selftest scope.

## Maintenance notes

- Keep selftests fast (<30s total); no network.
- When adding new orchestration scripts, add `--selftest` by convention.
- Reviewers: ensure mocks don't diverge from real runner output format.
