#!/usr/bin/env bash
# planner.sh — the "Sr TPM" stage (P-now of the North Star phase ladder).
#
# WHY THIS EXISTS (PART C.3 #1, the highest-leverage zero-research-risk move):
# A.1 ("prompt ANY task") and A.7 ("full senior org") are missing their FRONT —
# the step that turns one arbitrary task into a DAG of work-items tagged
# parallel (independent -> fan out) vs stacked (dependent -> serial chain).
# This is that step. It is "just another gated coding task": an LLM proposes the
# DAG, and a DETERMINISTIC gate proves the DAG is well-formed before anyone trusts
# it. Same discipline as C0: deterministic gate over LLM assertion; a malformed or
# cyclic plan is REJECTED, never silently accepted.
#
# Invariants preserved (same as gstack-review.sh):
#   TREE not mesh         — the planner is one leaf; it spawns nothing.
#   CONTRACTS not history — output is a typed DAG (the contract for gstack-loop),
#                           not a transcript.
#   GATE OUTSIDE WORKER   — validate_dag() is deterministic and runs in the driver,
#                           never in the proposing agent's scope.
#   DECASE: UNPARSEABLE=FAIL — a plan that doesn't parse is a hard reject (the
#                           verdict.sh spirit), so a bad plan can never pass as good.
#
# Output contract — a DAG as JSON on stdout (and saved to PLAN_OUT):
#   {
#     "task": "<original task>",
#     "nodes": [
#       {"id":"n1","title":"...","kind":"parallel|stack","deps":[],"stage":"build"},
#       ...
#     ]
#   }
# kind=parallel : independent of its siblings, may be fanned out.
# kind=stack    : must run after its deps, in serial order.
# stage         : a lifecycle stage from A.7 (discover|define|design|architect|
#                 build|review|qa|secure|release|document).
#
# Usage:
#   ./planner.sh "add OAuth login to the web app"           # propose + gate
#   ./planner.sh --validate plan.json                       # gate an existing DAG
#   PLANNER_MODEL=codex ./planner.sh "..."                  # any runner token
#   ./planner.sh --selftest                                 # offline POC gate proof
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runner.sh
[ -f "$HERE/lib/runner.sh" ] && . "$HERE/lib/runner.sh"

PLANNER_MODEL="${PLANNER_MODEL:-claude:sonnet}"
PLAN_OUT="${PLAN_OUT:-}"
LIFECYCLE_STAGES="discover define design architect build review qa secure release document"

_have_jq() { command -v jq >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# validate_dag <plan-file>  — THE GATE. Deterministic. Exit 0 = valid plan.
# Checks, in order (any failure prints a REASON: line and returns non-zero):
#   1. parses as JSON                       (else UNPARSEABLE)
#   2. has a non-empty nodes[] array
#   3. every node has id/title/kind/deps/stage of the right type
#   4. ids are unique
#   5. kind is parallel|stack ; stage is a known lifecycle stage
#   6. every dep references a real node id (no dangling edges)
#   7. the dep graph is acyclic (a stacked plan with a cycle can never run)
#   8. a parallel node declares NO deps (parallel = independent, by definition)
# Requires jq. Without jq the gate refuses to pass (fail-closed, never fail-open).
# ---------------------------------------------------------------------------
validate_dag() {
  local f="${1:?plan file}"
  [ -f "$f" ] || { echo "REASON: plan file not found: $f"; return 2; }
  if ! _have_jq; then
    echo "REASON: jq required for the planner gate; refusing to pass without it (fail-closed)"
    return 3
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "REASON: UNPARSEABLE — not valid JSON"
    return 1
  fi
  local nnodes
  nnodes="$(jq -r '.nodes | length' "$f" 2>/dev/null || echo 0)"
  if [ "$nnodes" -lt 1 ] 2>/dev/null; then
    echo "REASON: plan has no nodes"
    return 1
  fi
  # per-node shape + enum checks (jq returns the id of the first offending node)
  local bad
  bad="$(jq -r --arg stages "$LIFECYCLE_STAGES" '
    ($stages | split(" ")) as $valid
    | [ .nodes[]
        | select(
            (.id|type) != "string"
            or (.title|type) != "string"
            or (.kind|type) != "string"
            or (.deps|type) != "array"
            or (.stage|type) != "string"
            or ((.kind=="parallel" or .kind=="stack")|not)
            or (.stage as $s | ($valid | index($s)) == null)
          )
        | .id // "(missing id)" ] | .[0] // empty' "$f" 2>/dev/null)"
  if [ -n "$bad" ]; then
    echo "REASON: node '$bad' has bad shape / unknown kind / unknown stage"
    return 1
  fi
  # unique ids
  local dupes
  dupes="$(jq -r '[.nodes[].id] | (length) as $n | unique | length | if . == $n then "" else "dup" end' "$f")"
  [ "$dupes" = "dup" ] && { echo "REASON: duplicate node ids"; return 1; }
  # parallel nodes must have no deps
  local par_with_deps
  par_with_deps="$(jq -r '[.nodes[] | select(.kind=="parallel" and (.deps|length)>0) | .id] | .[0] // empty' "$f")"
  [ -n "$par_with_deps" ] && { echo "REASON: parallel node '$par_with_deps' declares deps (parallel = independent)"; return 1; }
  # dangling deps: every dep must be a known id
  local dangling
  dangling="$(jq -r '
    [.nodes[].id] as $ids
    | [ .nodes[] | .deps[] | select( . as $d | ($ids | index($d)) | not ) ] | .[0] // empty' "$f")"
  [ -n "$dangling" ] && { echo "REASON: dangling dependency '$dangling' references no node"; return 1; }
  # acyclicity: Kahn's algorithm in jq — repeatedly remove nodes all of whose deps
  # are already removed (i.e. NOT in the remaining set). If nodes remain after a
  # full pass removes nothing, there is a cycle. N iterations always suffice.
  local leftover
  leftover="$(jq -r '
    (reduce .nodes[] as $n ({}; .[$n.id] = $n.deps)) as $deps
    | reduce range(0; (.nodes|length)) as $_ (
        [.nodes[].id];
        . as $rem
        | ( [ $rem[] | select( ($deps[.] // []) | all( . as $d | ($rem | index($d)) | not ) ) ] ) as $removable
        | if ($removable|length) == 0 then $rem else ($rem - $removable) end
      ) | length' "$f" 2>/dev/null || echo 1)"
  if [ "${leftover:-1}" != "0" ]; then
    echo "REASON: dependency cycle detected (stacked plan cannot run)"
    return 1
  fi
  echo "VALID: $nnodes nodes, acyclic, deps resolve, tags well-formed"
  return 0
}

# ---------------------------------------------------------------------------
# propose_dag <task>  — ask the planner LLM for a DAG. Writes raw to $1out.
# Uses lib/runner.sh run_agent so ANY provider token works (A.5).
# ---------------------------------------------------------------------------
propose_dag() {
  local task="$1" outfile="$2" pf
  pf="$(mktemp)"; trap 'rm -f "${pf:-}"; trap - RETURN' RETURN
  cat > "$pf" <<EOF
You are a senior Technical Program Manager. Decompose the TASK below into a DAG of
work-items. Output ONLY a JSON object, no prose, no code fence, with this exact shape:

{"task":"<the task>","nodes":[
  {"id":"n1","title":"<short imperative>","kind":"parallel|stack","deps":["<id>",...],"stage":"<lifecycle>"}
]}

Rules (the gate enforces all of these — a violation causes PLAN REJECTED):
- kind="parallel" => node is INDEPENDENT; deps field MUST be exactly []. NO EXCEPTIONS.
  ERROR: {"kind":"parallel","deps":["n1"]} — parallel nodes CANNOT have deps.
- kind="stack" => node runs AFTER its deps complete; deps list the prerequisite node ids.
- deps reference other node ids only. The graph MUST be acyclic.
- stage is one of: $LIFECYCLE_STAGES
- Prefer parallel where work is genuinely independent; stack only true dependencies.
- A node that needs a prior node's output is ALWAYS kind="stack", never kind="parallel".

TASK: $task
EOF
  if command -v run_agent >/dev/null 2>&1; then
    run_agent "$PLANNER_MODEL" "$pf" "$outfile"
  else
    echo "REASON: lib/runner.sh not available; cannot propose (use --validate or --selftest)" >&2
    return 4
  fi
  # strip an accidental ```json fence if the model added one
  if [ -s "$outfile" ]; then
    sed -E '/^```/d' "$outfile" > "$outfile.clean" && mv "$outfile.clean" "$outfile"
  fi
}

# ---------------------------------------------------------------------------
# selftest — OFFLINE proof of the gate (no API). Injects known DAGs and asserts
# the gate's verdict on each. This is the POC's falsifiable evidence.
# ---------------------------------------------------------------------------
selftest() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:-}"; trap - RETURN' RETURN
  local pass=0 fail=0
  _ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
  _no(){ echo "  ❌ $1"; fail=$((fail+1)); }

  # 1. honest valid DAG -> VALID
  cat > "$tmp/good.json" <<'J'
{"task":"add oauth","nodes":[
 {"id":"d","title":"discover providers","kind":"parallel","deps":[],"stage":"discover"},
 {"id":"s","title":"write spec","kind":"stack","deps":["d"],"stage":"define"},
 {"id":"b","title":"implement","kind":"stack","deps":["s"],"stage":"build"},
 {"id":"q","title":"qa matrix","kind":"stack","deps":["b"],"stage":"qa"}]}
J
  validate_dag "$tmp/good.json" >/dev/null 2>&1 && _ok "honest valid DAG -> VALID" || _no "valid DAG wrongly rejected"

  # 2. cyclic DAG -> REJECT
  cat > "$tmp/cycle.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"stack","deps":["b"],"stage":"build"},
 {"id":"b","title":"b","kind":"stack","deps":["a"],"stage":"build"}]}
J
  validate_dag "$tmp/cycle.json" >/dev/null 2>&1 && _no "cycle NOT caught" || _ok "cyclic DAG -> REJECT"

  # 3. dangling dep -> REJECT
  cat > "$tmp/dangle.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"stack","deps":["ghost"],"stage":"build"}]}
J
  validate_dag "$tmp/dangle.json" >/dev/null 2>&1 && _no "dangling dep NOT caught" || _ok "dangling dep -> REJECT"

  # 4. parallel node with deps -> REJECT (parallel = independent)
  cat > "$tmp/parwd.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"stack","deps":[],"stage":"build"},
 {"id":"b","title":"b","kind":"parallel","deps":["a"],"stage":"build"}]}
J
  validate_dag "$tmp/parwd.json" >/dev/null 2>&1 && _no "parallel-with-deps NOT caught" || _ok "parallel node w/ deps -> REJECT"

  # 5. unknown stage -> REJECT
  cat > "$tmp/badstage.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"stack","deps":[],"stage":"deploy-to-mars"}]}
J
  validate_dag "$tmp/badstage.json" >/dev/null 2>&1 && _no "unknown stage NOT caught" || _ok "unknown stage -> REJECT"

  # 6. malformed JSON -> UNPARSEABLE REJECT
  printf 'this is not json {' > "$tmp/bad.json"
  validate_dag "$tmp/bad.json" >/dev/null 2>&1 && _no "malformed JSON NOT caught" || _ok "malformed JSON -> UNPARSEABLE reject"

  # 7. empty nodes -> REJECT
  echo '{"task":"x","nodes":[]}' > "$tmp/empty.json"
  validate_dag "$tmp/empty.json" >/dev/null 2>&1 && _no "empty nodes NOT caught" || _ok "empty nodes -> REJECT"

  # 8. duplicate ids -> REJECT
  cat > "$tmp/dup.json" <<'J'
{"task":"x","nodes":[
 {"id":"a","title":"a","kind":"parallel","deps":[],"stage":"build"},
 {"id":"a","title":"a2","kind":"parallel","deps":[],"stage":"qa"}]}
J
  validate_dag "$tmp/dup.json" >/dev/null 2>&1 && _no "duplicate ids NOT caught" || _ok "duplicate ids -> REJECT"

  echo
  echo "== planner gate selftest: $pass passed, $fail failed =="
  [ "$fail" -eq 0 ] && { echo "GATE PROVEN — accepts well-formed DAGs, rejects all 7 malformations."; return 0; }
  echo "GATE BROKEN — a malformation slipped through."; return 1
}

main() {
  case "${1:-}" in
    --selftest) selftest ;;
    --validate)
      [ -n "${2:-}" ] || { echo "usage: $0 --validate <plan.json>" >&2; exit 2; }
      validate_dag "$2"; exit $? ;;
    ""|-h|--help)
      sed -n '2,40p' "$0"; exit 0 ;;
    *)
      local task="$*" out; out="${PLAN_OUT:-$(mktemp)}"
      propose_dag "$task" "$out" || exit $?
      if validate_dag "$out"; then
        echo "---"; cat "$out"
        [ -n "$PLAN_OUT" ] && echo "(saved to $PLAN_OUT)" >&2
        exit 0
      else
        echo "PLAN REJECTED — the proposed DAG failed the deterministic gate (above). Not trusted." >&2
        exit 1
      fi ;;
  esac
}
main "$@"
