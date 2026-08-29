# Plan 003: Implement parallel fan-out in gstack-loop batches

> **Executor instructions**: Follow this plan step by step. Run every verification
> command and confirm the expected result before moving to the next step. If anything
> in the "STOP conditions" section occurs, stop and report — do not improvise. When
> done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 3ffc4dc..HEAD -- gstack-loop.sh gstack-review.sh fanout.sh`
> If any in-scope file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-wire-gstack-review-commit-gate.md
- **Category**: bug | perf
- **Planned at**: commit `3ffc4dc`, 2026-08-29

## Why this matters

`gstack-loop.sh` schedules DAG nodes into batches where nodes in the same batch are
independent. Comments and README describe within-batch fan-out, but `drive()` runs
`run_node` in a serial `for` loop. Independent nodes (e.g. diamond DAG siblings b and c)
execute one after another, wasting wall-clock time and violating documented semantics.

## Current state

- `gstack-loop.sh` — outer gstack state machine; `schedule_dag` produces `BATCH: id id ...` lines.
- `gstack-review.sh` — invoked per node via `run_node`.
- `fanout.sh` — reference for parallel spawn + `wait` pattern (intra-session fan-out).

Excerpt — serial execution despite batch comment (`gstack-loop.sh:101-111`):

```bash
echo; echo "== SCHEDULE (batches are serial; ids within a batch fan out) =="
# ...
printf '%s\n' "$sched" | while IFS= read -r line; do
  case "$line" in
    BATCH*)
      local ids="${line#*: }"
      for id in $ids; do run_node "$plan" "$id"; done ;;
  esac
done
```

Selftest already validates scheduling (diamond puts b,c in same batch) but not parallel execution.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Scheduler selftest | `bash gstack-loop.sh --selftest` | 8 passed |
| Shellcheck | `shellcheck -S warning gstack-loop.sh` | exit 0 |
| Timing test (new) | selftest case with sleep stubs | parallel < serial |

## Scope

**In scope**:
- `gstack-loop.sh` — parallelize within-batch `run_node` calls

**Out of scope**:
- Cross-batch parallelism (batches must stay serial for DAG correctness).
- Replacing `gstack-review.sh` with `fanout.sh` (different abstraction level).
- Real agent execution in selftest (use stub/mock `GSTACK_EXECUTE=0` or test hooks).

## Git workflow

- Branch: `advisor/003-gstack-loop-parallel-fanout`
- Commit message: `fix(gstack-loop): fan out independent batch nodes in parallel`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Parallelize batch inner loop

Replace serial `for id in $ids; do run_node ...; done` with background jobs + `wait`:

```bash
local pids=()
for id in $ids; do
  run_node "$plan" "$id" &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
```

Collect exit codes; if any node fails, propagate failure (document behavior: fail-fast
after batch completes vs fail on first — prefer fail-fast with `wait` exit status check).

**Verify**: `bash -n gstack-loop.sh` → exit 0

### Step 2: Add selftest for parallel execution

Add a selftest case that stubs `run_node` or uses `GSTACK_EXECUTE=0` with a wrapper
that sleeps 1s per node. For a 2-node batch, serial would take ~2s, parallel ~1s.
Use `date +%s` timing with generous margin, or count concurrent marker files.

**Verify**: `bash gstack-loop.sh --selftest` → 9+ passed (one new case), exit 0

### Step 3: Document failure semantics

Update header comment in `gstack-loop.sh` if batch failure behavior changes (e.g. all
nodes in batch run even if one fails, vs cancel siblings).

**Verify**: comment matches implementation.

## Test plan

- Existing diamond scheduling selftest still passes.
- New parallel timing/concurrency selftest passes.
- Manual (optional): `GSTACK_EXECUTE=1` with two quick nodes — observe overlapping logs.

## Done criteria

- [ ] Within-batch nodes run concurrently (background + wait)
- [ ] `bash gstack-loop.sh --selftest` exits 0 with parallel case
- [ ] `shellcheck -S warning gstack-loop.sh` exits 0
- [ ] Batch failure behavior documented and tested
- [ ] `plans/README.md` status row for 003 updated to DONE

## STOP conditions

- `run_node` uses shared mutable state unsafe for parallel runs — serialize or isolate first.
- `GSTACK_EXECUTE` dry-run path cannot be tested — report and propose manual verification.
- Subshell `while read` loses `pids` — refactor loop structure if needed.

## Maintenance notes

- Parallel nodes each invoke `gstack-review.sh` on the same repo — ensure git worktree
  isolation or sequential repo access if conflicts appear (may need worktrees in future).
- Reviewers: watch for race on shared `RUNS_ROOT` paths; each node should use distinct run dir.
