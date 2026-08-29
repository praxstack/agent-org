# Plan 005: Parallelize gstack-loop batch execution

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- gstack-loop.sh tests/ README.md`
> On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/002-orchestration-test-harness-ci.md
- **Category**: perf
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

README states gstack-loop "Fan-out happens only at genuinely independent batches"
and that ids within a batch "fan out". Implementation in `drive()` walks each
batch with a serial `for id in $ids; do run_node ...; done` loop (lines 106–111).
Independent planner nodes therefore run one-at-a-time, wasting wall-clock when
`GSTACK_EXECUTE=1` and multiple parallel nodes exist. The scheduler already
computes correct batches; execution should match the documented topology.

## Current state

- `schedule_dag` in `gstack-loop.sh` (lines 47–67) emits `BATCH n: id id ...`.
- Serial execution (lines 106–111):

```106:111:gstack-loop.sh
  printf '%s\n' "$sched" | while IFS= read -r line; do
    case "$line" in
      BATCH*)
        local ids="${line#*: }"
        for id in $ids; do run_node "$plan" "$id"; done ;;
    esac
  done
```

- `gstack-loop.sh --selftest` already validates scheduling and mock exec order
  (lines 160–184) but uses the same serial loop in the mock path.
- `fanout.sh` uses background jobs + `wait` with `FANOUT_CONCURRENCY` — use as
  concurrency pattern reference (lines 66–73).

Env to add: `GSTACK_BATCH_CONCURRENCY` (default 4 or unset = unlimited within batch).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Scheduler selftest | `bash gstack-loop.sh --selftest` | 8 passed, 0 failed |
| Full harness | `bash tests/run-orchestration-tests.sh` | exit 0 |
| shellcheck | `shellcheck -S warning gstack-loop.sh` | exit 0 |

## Scope

**In scope**:
- `gstack-loop.sh` — parallel batch execution + selftest update
- `tests/test-gstack-parallel.sh` (new, optional timing-free proof)
- `README.md` — document `GSTACK_BATCH_CONCURRENCY` (one env table row)

**Out of scope**:
- Parallelizing across batches (still serial between batches)
- Shared-repo write conflicts — document that parallel nodes must target disjoint paths
- `fanout.sh` changes

## Git workflow

- Branch: `advisor/005-gstack-parallel-batches`
- Commit: `feat(gstack-loop): run independent batch nodes concurrently`
- Do NOT push unless instructed.

## Steps

### Step 1: Add `run_batch` helper

In `gstack-loop.sh`, replace the inner `for id in $ids` loop with:

```bash
run_batch() {
  local plan="$1" ids="$2"
  local id pids=() n=0 max="${GSTACK_BATCH_CONCURRENCY:-0}"
  for id in $ids; do
    run_node "$plan" "$id" &
    pids+=($!)
    n=$((n+1))
    if [ "$max" -gt 0 ] && [ $(( n % max )) -eq 0 ]; then wait; pids=(); fi
  done
  wait
}
```

Collect non-zero exit codes: if any `run_node` fails, propagate failure at batch
level (echo warning + return 1) so `drive()` can surface partial batch failure.

**Verify**: `bash -n gstack-loop.sh` → exit 0.

### Step 2: Update selftest mock path

In `selftest` execution-path proof (lines 171–175), use `run_batch` instead of
serial loop. Add assertion that mock commands can detect concurrent launch if
feasible (optional): mock script sleeps 0.5s and writes PID; with concurrency 2
and 2 nodes in batch 2, total time < 0.9s serial would be > 1.0s.

Minimum: still assert topological order in trace file (existing checks).

**Verify**: `bash gstack-loop.sh --selftest` → 8 passed (update count if new case).

### Step 3: Add concurrency regression test

`tests/test-gstack-parallel.sh`:

1. Build diamond plan (same as selftest).
2. Mock `GSTACK_REVIEW_CMD` script that `sleep 1` then echoes id.
3. Run batch 2 (two nodes) with `GSTACK_BATCH_CONCURRENCY=2` and time the batch
   (or compare start timestamps in log).
4. Assert elapsed < 1.5s (parallel) not > 1.8s (serial).

Add to orchestration harness.

**Verify**: `bash tests/test-gstack-parallel.sh` → exit 0.

### Step 4: Document env var and caveat

README: add `GSTACK_BATCH_CONCURRENCY` — max parallel nodes per batch (0 = unlimited).

One sentence caveat: parallel nodes must not conflict on same files; planner should
decompose accordingly.

**Verify**: grep shows new env row.

## Test plan

- `--selftest` remains offline.
- `tests/test-gstack-parallel.sh` uses sleep timing (allow generous threshold on CI).

**Verify**: `bash tests/run-orchestration-tests.sh` → exit 0.

## Done criteria

- [ ] Independent nodes in same batch launch concurrently (background jobs)
- [ ] Batches still run serially in order
- [ ] `GSTACK_BATCH_CONCURRENCY` respected when set
- [ ] `bash gstack-loop.sh --selftest` passes
- [ ] Parallel timing test in harness passes
- [ ] README documents new env var
- [ ] `shellcheck -S warning gstack-loop.sh` exits 0
- [ ] `plans/README.md` row 005 updated

## STOP conditions

- `run_node` or `GSTACK_EXECUTE` semantics changed making background unsafe — STOP.
- Selftest mock path cannot be updated without breaking topological proof.
- CI environment forbids background jobs in test (unlikely) — report and relax test.

## Maintenance notes

- When `GSTACK_EXECUTE=1` hits real repos, parallel writes to same files remain
  user/planner responsibility — consider future planner constraint "parallel nodes
  must declare disjoint paths".
