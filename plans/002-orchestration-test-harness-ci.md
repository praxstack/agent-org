# Plan 002: Add orchestration test harness and CI coverage

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- tests/ .github/workflows/ci.yml planner.sh gstack-loop.sh fanout.sh lib/ hooks/`
> If any in-scope file changed since this plan was written, compare excerpts
> before proceeding; on mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

CI today runs only `planner.sh --selftest`, `gstack-loop.sh --selftest`, inline
heldout-gate checks, verdict fail-closed checks, and three block-commit smoke
cases. There is no unified test entrypoint, no coverage for `fanout.sh` ledger
join, `lib/runner.sh` normalization paths, or `fanout.sh` RUN_ID validation.
Orchestration regressions in lib code can ship while planner/scheduler selftests
still pass. A single `tests/run-orchestration-tests.sh` gives executors and CI a
verification baseline before riskier gate changes (Plans 001, 003, 004, 005).

## Current state

- `.github/workflows/ci.yml` — three jobs: shellcheck, selftests, gate-smoke.
- Existing offline proofs embedded in scripts:
  - `planner.sh --selftest` (8 gate malformation classes)
  - `gstack-loop.sh --selftest` (scheduler + mock exec path)
- `fanout.sh` has RUN_ID fail-closed check (lines 18–19) but no CI test.
- `lib/verdict.sh` has partial CI in workflow; not invoked as a library from a
  named test script.
- No `tests/` directory at repo root today.

Repo conventions: bash 3.2, `set -uo pipefail`, tests should be offline (no API
keys, no `claude` calls). Follow CONTRIBUTING: `bash -n` on every new script.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Run all orchestration tests | `bash tests/run-orchestration-tests.sh` | exit 0, all ✅ |
| Existing selftests | `bash planner.sh --selftest` | 8 passed, 0 failed |
| Scheduler selftest | `bash gstack-loop.sh --selftest` | 8 passed, 0 failed |
| shellcheck | `shellcheck -S warning tests/*.sh` | exit 0 |
| Syntax | `bash -n tests/run-orchestration-tests.sh` | exit 0 |

## Scope

**In scope**:
- `tests/run-orchestration-tests.sh` (new — top-level runner)
- `tests/test-verdict.sh` (new)
- `tests/test-fanout-runid.sh` (new)
- `tests/test-ledger.sh` (new)
- `.github/workflows/ci.yml` (add job or step invoking the runner)

**Out of scope**:
- Live agent tests requiring `claude`, `hermes`, etc.
- Vendored skills under `.claude/skills/`, `.agents/`, `.agnets/`
- `scripts/install-skill-packs.sh` (network/git clone tests)

## Git workflow

- Branch: `advisor/002-orchestration-test-harness`
- Commit per test file or one commit for harness + CI — prefer one logical commit:
  `test: add orchestration test harness and CI job`
- Do NOT push unless instructed.

## Steps

### Step 1: Create `tests/run-orchestration-tests.sh`

Top-level runner that:
1. `set -uo pipefail`
2. Resolves repo root from its own location (same self-locate pattern as
   `review-loop.sh`)
3. Runs in order, failing fast on first failure:
   - `bash planner.sh --selftest`
   - `bash gstack-loop.sh --selftest`
   - `bash tests/test-verdict.sh`
   - `bash tests/test-fanout-runid.sh`
   - `bash tests/test-ledger.sh`
4. Prints summary line `OK: orchestration tests` on success.

Make executable: `chmod +x tests/run-orchestration-tests.sh`.

**Verify**: `bash tests/run-orchestration-tests.sh` → exit 0.

### Step 2: Add `tests/test-verdict.sh`

Offline tests sourcing `lib/verdict.sh`. Cover at least:

1. Mixed verdict `FAIL (was PASS in round 1)` → token `FAIL` (fail-closed).
2. Junk verdict line → `UNPARSEABLE`.
3. `verdict_aggregate` with one PASS + one FAIL → `FAIL`.
4. Empty leaf file → `UNPARSEABLE`.
5. Canonical PASS block → `PASS`.

Use temp files under `mktemp -d`; no jq required for verdict tests.

**Verify**: `bash tests/test-verdict.sh` → exit 0.

### Step 3: Add `tests/test-fanout-runid.sh`

Test `fanout.sh` RUN_ID validation without spawning agents:

```bash
# expect exit 2, no ledger created under /tmp/evil
bash fanout.sh /dev/null '../evil' 2>/dev/null; echo rc=$?
bash fanout.sh /dev/null 'foo/bar' 2>/dev/null; echo rc=$?
```

Assert both return rc=2 and stderr contains `invalid run_id`.

**Verify**: `bash tests/test-fanout-runid.sh` → exit 0.

### Step 4: Add `tests/test-ledger.sh`

Source `lib/ledger.sh` in a temp dir:

1. `ledger_init test-run "$tmp/ledger.jsonl"` → file exists, one init line.
2. `ledger_event review actor model spawn "input" "" ""` → `ledger_count spawn` is 1.
3. Content hashes present (non-empty `input_hash` when input provided).

**Verify**: `bash tests/test-ledger.sh` → exit 0.

### Step 5: Wire CI

In `.github/workflows/ci.yml`, add a step or job:

```yaml
- name: orchestration test harness
  run: bash tests/run-orchestration-tests.sh
```

Place it in the existing `selftests` job after planner/gstack selftests OR replace
duplicate calls with the single runner (runner already invokes them — prefer one
call to avoid double-running).

**Verify**: read workflow YAML; ensure only one invocation of each selftest.

## Test plan

- The harness itself is the test plan; CI must call it.
- Model after existing inline CI checks in `.github/workflows/ci.yml` (explicit
  `[ "$rc" -eq N ]` assertions with echo OK/FAIL).

**Verify**: `bash tests/run-orchestration-tests.sh` → all subtests pass.

## Done criteria

- [ ] `tests/run-orchestration-tests.sh` exists, executable, exit 0 locally
- [ ] At least 3 new test scripts under `tests/` covering verdict, fanout RUN_ID, ledger
- [ ] CI workflow invokes the harness
- [ ] `shellcheck -S warning tests/*.sh` exits 0
- [ ] `bash -n` passes on all new scripts
- [ ] No live network or API calls in tests
- [ ] `plans/README.md` row 002 updated

## STOP conditions

- Repo already has a conflicting `tests/` tree with different purpose — STOP and
  report; propose merge strategy.
- `fanout.sh` RUN_ID validation was removed — excerpt mismatch.
- CI workflow structure changed making step insertion ambiguous.

## Maintenance notes

- Plans 001, 003, 004, 005 should add cases to this harness rather than one-off
  CI snippets.
- Keep tests offline; integration tests with real `claude` belong in CONTRIBUTING
  manual checklist, not CI.
