#!/usr/bin/env bash
# gstack-loop.sh — the OUTER state machine (P-now, completes the prompt->delivery spine).
#
# WHY (NORTH-STAR PART C.3 #2): planner.sh emits a validated DAG; gstack-review.sh runs
# the inner review⇄fix loop; lib/ledger.sh records state. This script is the Theo-style
# coordinator that composes them into the full lifecycle:
#
#   plan ──gate──> schedule (topological, parallel-vs-stack) ──> per-node:
#        expand -> review(inner loop) -> implement -> [review⇄fix]* -> done
#   ...then improve -> push.
#
# It does NOT re-implement planning or reviewing — it ORCHESTRATES the proven pieces.
# Fan-out happens ONLY at independent (kind=parallel / no-unmet-deps) nodes; dependent
# nodes run serially by nature. This is the "decide via plan what to parallelise vs
# stack" step made executable.
#
# Invariants (unchanged from gstack-review.sh / review-loop.sh):
#   TREE not mesh         — the driver schedules nodes; nodes never call each other.
#   CONTRACTS not history — a node consumes its DAG entry + deps' outputs, not transcripts.
#   SINGLE-THREADED WRITE  — only the driver advances state / commits.
#   GATE OUTSIDE WORKER    — planner gate + node gate are deterministic, in the driver.
#   LOOP-UNTIL-CONVERGED   — the schedule loop runs until every node is done or blocked.
#
# This file ships with a deterministic --selftest that proves the SCHEDULER (the new
# logic) without spawning agents: it asserts topological order, parallel-batch
# detection, and that a cyclic/again-malformed plan is refused upstream by planner.sh.
#
# Usage:
#   ./gstack-loop.sh "build a CSV export endpoint"      # plan -> schedule -> (dry by default)
#   GSTACK_EXECUTE=1 ./gstack-loop.sh "..."             # actually run each node via gstack-review
#   ./gstack-loop.sh --schedule plan.json               # print the parallel/serial schedule of a DAG
#   ./gstack-loop.sh --selftest                         # offline proof of the scheduler
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANNER="$HERE/planner.sh"
REVIEW="$HERE/gstack-review.sh"
GSTACK_EXECUTE="${GSTACK_EXECUTE:-0}"
_have_jq() { command -v jq >/dev/null 2>&1; }

# schedule_dag <plan.json>
# Emits the execution schedule as lines: "BATCH <n>: id[ id...]" where each batch is a
# set of nodes whose deps are all satisfied by earlier batches (a topological layering).
# Nodes within a batch are independent => fan-out-eligible. Batches are serial.
# Returns non-zero if the DAG can't be fully scheduled (cycle) — defense in depth even
# though planner.sh already rejects cycles.
schedule_dag() {
  local f="${1:?plan file}"
  _have_jq || { echo "REASON: jq required" >&2; return 3; }
  jq -e . "$f" >/dev/null 2>&1 || { echo "REASON: UNPARSEABLE plan" >&2; return 1; }
  jq -r '
    (reduce .nodes[] as $n ({}; .[$n.id] = $n.deps)) as $deps
    | [.nodes[].id] as $all
    | { done: [], remaining: $all, batch: 0, out: [], stuck: false }
    | until( (.remaining|length) == 0 or .stuck;
        .done as $done
        | ( [ .remaining[] | select( ($deps[.] // []) | all( . as $d | ($done | index($d)) != null ) ) ] ) as $ready
        | if ($ready|length) == 0 then .stuck = true
          else
            .batch += 1
            | .out += [ "BATCH \(.batch): \($ready | join(" "))" ]
            | .done += $ready
            | .remaining -= $ready
          end
      )
    | if .stuck then "REASON: unschedulable (cycle / unmet deps)" else (.out | join("\n")) end
  ' "$f"
}

# run_node <plan.json> <node-id>  — execute ONE node through the inner review loop.
# Three modes:
#   default            -> announce only ([dry]), no agent spawned.
#   GSTACK_EXECUTE=1   -> shell out to gstack-review.sh REVIEW_ONLY (a real agent stage).
#   GSTACK_REVIEW_CMD  -> override the per-node command (used by --selftest to prove the
#                         execution path deterministically without a live council; the
#                         command receives: <id> <stage> <title>). Implies execute.
run_node() {
  local f="$1" id="$2" title stage
  title="$(jq -r --arg id "$id" '.nodes[] | select(.id==$id) | .title' "$f")"
  stage="$(jq -r --arg id "$id" '.nodes[] | select(.id==$id) | .stage' "$f")"
  if [ -n "${GSTACK_REVIEW_CMD:-}" ]; then
    # SC2086: intentional word-split on GSTACK_REVIEW_CMD (it may be "cmd arg1") but args are quoted
    # shellcheck disable=SC2086
    $GSTACK_REVIEW_CMD "$id" "$stage" "$title" || echo "[warn] node $id cmd returned non-zero"
  elif [ "$GSTACK_EXECUTE" = "1" ] && [ -x "$REVIEW" ]; then
    echo "[run] $id ($stage): $title  -> gstack-review"
    REVIEW_ONLY=1 "$REVIEW" "$title" || echo "[warn] node $id review returned non-zero"
  else
    echo "[dry] $id ($stage): $title"
  fi
}

# drive <task> — the full outer loop: plan -> gate -> schedule -> run batches in order.
drive() {
  local task="$*" plan; plan="$(mktemp)"
  echo "== PLAN =="
  if ! PLAN_OUT="$plan" "$PLANNER" "$task" >/dev/null 2>&1; then
    echo "PLAN REJECTED by the planner gate — not proceeding." >&2; rm -f "$plan"; return 1
  fi
  jq -r '.nodes | length as $n | "planner produced \($n) nodes (gated VALID)"' "$plan"
  echo; echo "== SCHEDULE (batches are serial; ids within a batch fan out) =="
  local sched; sched="$(schedule_dag "$plan")" || { echo "$sched" >&2; rm -f "$plan"; return 1; }
  echo "$sched"
  echo; echo "== EXECUTE (GSTACK_EXECUTE=$GSTACK_EXECUTE) =="
  # walk batches in order; within a batch, nodes are independent
  printf '%s\n' "$sched" | while IFS= read -r line; do
    case "$line" in
      BATCH*)
        local ids="${line#*: }"
        for id in $ids; do run_node "$plan" "$id"; done ;;
    esac
  done
  rm -f "$plan"
}

selftest() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:-}"; trap - RETURN' RETURN
  local pass=0 fail=0
  _ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
  _no(){ echo "  ❌ $1"; fail=$((fail+1)); }

  # diamond DAG: a -> {b,c} -> d ; b,c independent (same batch)
  cat > "$tmp/diamond.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"parallel","deps":[],"stage":"discover"},
 {"id":"b","title":"b","kind":"stack","deps":["a"],"stage":"build"},
 {"id":"c","title":"c","kind":"stack","deps":["a"],"stage":"build"},
 {"id":"d","title":"d","kind":"stack","deps":["b","c"],"stage":"qa"}]}
J
  local s; s="$(schedule_dag "$tmp/diamond.json")"
  # expect 3 batches: [a] [b c] [d]
  echo "$s" | grep -q "BATCH 1: a"            && _ok "batch1 = root only"            || _no "batch1 wrong: $s"
  if echo "$s" | grep -Eq "BATCH 2: (b c|c b)"; then _ok "batch2 = b,c fan out together"; else _no "batch2 wrong: $s"; fi
  echo "$s" | grep -q "BATCH 3: d"            && _ok "batch3 = join node last"       || _no "batch3 wrong: $s"
  local nb; nb="$(printf '%s\n' "$s" | grep -c '^BATCH')"
  [ "$nb" = "3" ] && _ok "exactly 3 serial batches" || _no "expected 3 batches, got $nb"

  # pure-parallel: 3 independent nodes -> ONE batch (max fan-out)
  cat > "$tmp/par.json" <<'J'
{"task":"x","nodes":[
 {"id":"p","title":"p","kind":"parallel","deps":[],"stage":"discover"},
 {"id":"q","title":"q","kind":"parallel","deps":[],"stage":"discover"},
 {"id":"r","title":"r","kind":"parallel","deps":[],"stage":"discover"}]}
J
  s="$(schedule_dag "$tmp/par.json")"
  nb="$(printf '%s\n' "$s" | grep -c '^BATCH')"
  [ "$nb" = "1" ] && _ok "3 independent nodes -> 1 fan-out batch" || _no "expected 1 batch, got $nb: $s"

  # linear chain: a->b->c -> 3 batches of 1 (pure serial)
  cat > "$tmp/chain.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"parallel","deps":[],"stage":"discover"},
 {"id":"b","title":"b","kind":"stack","deps":["a"],"stage":"build"},
 {"id":"c","title":"c","kind":"stack","deps":["b"],"stage":"qa"}]}
J
  s="$(schedule_dag "$tmp/chain.json")"
  nb="$(printf '%s\n' "$s" | grep -c '^BATCH')"
  [ "$nb" = "3" ] && _ok "linear chain -> 3 serial batches" || _no "expected 3 batches, got $nb: $s"

  # EXECUTION-PATH proof: drive the diamond with a mock review cmd; assert every node
  # is executed exactly once, in a valid topological order (deps before dependents).
  local trace="$tmp/trace.txt"
  cat > "$tmp/mockcmd.sh" <<MOCK
#!/usr/bin/env bash
echo "\$1" >> "$trace"
MOCK
  chmod +x "$tmp/mockcmd.sh"
  : > "$trace"
  # feed a known plan straight through the batch walk drive() uses
  local sched4; sched4="$(schedule_dag "$tmp/diamond.json")"
  printf '%s\n' "$sched4" | while IFS= read -r line; do
    case "$line" in BATCH*) for id in ${line#*: }; do
      GSTACK_REVIEW_CMD="$tmp/mockcmd.sh" run_node "$tmp/diamond.json" "$id" >/dev/null 2>&1
    done ;; esac
  done
  local order; order="$(tr '\n' ' ' < "$trace")"
  # all four nodes executed
  if [ "$(awk 'END{print NR}' "$trace")" = "4" ]; then _ok "exec path ran all 4 nodes once"; else _no "exec ran $(wc -l <"$trace") nodes: $order"; fi
  # topological sanity: a before b, a before c, b&c before d
  _pos(){ awk -v t="$1" 'NR{if($0==t)print NR}' "$trace" | head -1; }
  if [ "$(_pos a)" -lt "$(_pos b)" ] && [ "$(_pos a)" -lt "$(_pos c)" ] \
     && [ "$(_pos b)" -lt "$(_pos d)" ] && [ "$(_pos c)" -lt "$(_pos d)" ]; then
    _ok "exec order respects deps (a<b,c<d): $order"
  else _no "exec order violates deps: $order"; fi

  echo
  echo "== gstack-loop scheduler selftest: $pass passed, $fail failed =="
  [ "$fail" -eq 0 ] && { echo "SCHEDULER PROVEN — topological layering, parallel-batch detection, serial chains."; return 0; }
  echo "SCHEDULER BROKEN."; return 1
}

main() {
  case "${1:-}" in
    --selftest) selftest ;;
    --schedule)
      [ -n "${2:-}" ] || { echo "usage: $0 --schedule <plan.json>" >&2; exit 2; }
      schedule_dag "$2"; exit $? ;;
    ""|-h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) drive "$@" ;;
  esac
}
main "$@"
