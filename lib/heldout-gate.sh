#!/usr/bin/env bash
# lib/heldout-gate.sh — the C0 gate: a held-out, optimizer-unreachable grader.
#
# WHY THIS EXISTS (the verified differentiator, 2026-06-19): reproduce-first study
# of the four leading public self-improvers found that NONE enforces C0 on the
# open-ended path — each is defeatable by an optimizing agent:
#   - sia: grader sits in the public tree; private answers are one `../private` hop
#     from the dir the agent is handed; agents run bypassPermissions.
#   - auto-harness: the test-trace kill-switch lives INSIDE the agent file the
#     optimizer rewrites; results.tsv is gitignored so the file-guard can't see it.
#   - metabot: no gate at all — tasks auto-complete on process-exit / self-attest.
#   - autocontext: real process isolation for execution scenarios, BUT the
#     plain-language path scores via an LLM judging its own provider's output.
#
# agent-org's constitution C0 — "the optimizer never has write access to its own
# objective function or to the process that evaluates it" — was PROVEN in E2 (a
# held-out gate run from a clean cwd defeated pytest-shim / sitecustomize / a live
# cheat-pressured agent). This file packages that property as a reusable gate, and
# adds the PRE-FLIGHT INTEGRITY CHECK the E2 finding implies: before trusting a
# verdict, prove the grader was actually unreachable from the agent's write scope.
#
# It is intentionally a thin, auditable bash layer — the gate must be simpler than
# the thing it judges, and must not itself be LLM-driven (an LLM grader is gameable;
# that's the autocontext hole). It composes with lib/verdict.sh (emits the canonical
# VERDICT block) and is callable from review-loop.sh / gstack-review.sh / a forked
# self-improvement engine as the replacement for an in-tree or LLM judge.
#
# CONTRACT
#   heldout_gate <work_dir> <grader_path> [grader_args...]
#     work_dir     : the ONLY tree the optimizer/coder may write (its scope).
#     grader_path  : an executable grader OUTSIDE work_dir (held-out). It must
#                    print a final line "SCORE: <float>" (and exit 0) or fail.
#   Emits a canonical verdict block (VOICE: heldout-gate / VERDICT: PASS|FAIL|
#   UNPARSEABLE / FINDINGS:) on stdout and returns 0 on PASS, 1 on FAIL, 2 on a
#   STRUCTURAL VIOLATION (the gate could not guarantee C0 — treated as worse than
#   FAIL: never a silent pass).
#
# Env:
#   GATE_MIN_SCORE   pass threshold (default 1.0 — full pass; set per task)
#   GATE_BASELINE    optional prior score; PASS requires score >= max(min,baseline)
#                    (the ratchet — borrowed pattern from auto-harness/autocontext,
#                     but enforced OUTSIDE the agent's reach).
#   GATE_PIN_SHA     optional expected sha256 of the grader (C2 content-address:
#                    a grader whose hash changed = STRUCTURAL VIOLATION).
set -uo pipefail

_HG_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$_HG_DIR/verdict.sh" ] && . "$_HG_DIR/verdict.sh"

# _hg_sha <file> — portable sha256 (macOS shasum / linux sha256sum).
_hg_sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum  >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else echo "NO_SHA_TOOL"; fi
}

# _hg_realpath <path> — resolve to an absolute, symlink-free path (portable).
_hg_realpath() {
  if command -v realpath >/dev/null 2>&1; then realpath "$1" 2>/dev/null && return; fi
  # portable fallback
  local d b; d="$(cd -P "$(dirname "$1")" 2>/dev/null && pwd)"; b="$(basename "$1")"
  [ -n "$d" ] && printf '%s/%s' "$d" "$b" || printf '%s' "$1"
}

# _hg_emit <verdict> <finding...>  — print a canonical verdict.sh-shaped block.
_hg_emit() {
  local v="$1"; shift
  printf 'VOICE: heldout-gate\nVERDICT: %s\nFINDINGS:\n' "$v"
  if [ "$#" -eq 0 ]; then printf -- '- (none)\n'; else printf -- '- %s\n' "$@"; fi
}

# heldout_preflight <work_dir> <grader_path>
# The C0 guarantee, checked rather than assumed. Returns 0 iff the grader is
# provably OUTSIDE the optimizer's write scope. This is the check sia/auto-harness
# skip — and exactly why they're gameable.
heldout_preflight() {
  local work="$1" grader="$2" awork agrader
  [ -e "$grader" ] || { echo "grader not found: $grader"; return 2; }
  [ -x "$grader" ] || { echo "grader not executable: $grader"; return 2; }
  [ -d "$work" ]   || { echo "work_dir not a directory: $work"; return 2; }
  awork="$(_hg_realpath "$work")"
  agrader="$(_hg_realpath "$grader")"
  # VIOLATION 1 — grader lives inside the agent's write scope (auto-harness/sia hole).
  case "$agrader/" in
    "$awork"/*) echo "C0 VIOLATION: grader ($agrader) is INSIDE the optimizer write scope ($awork) — it could edit its own grader"; return 2 ;;
  esac
  # VIOLATION 2 — the agent's scope can traverse UP to the grader's dir (the sia
  # `../private` hop): if the grader's parent is an ancestor of work_dir, a
  # `../`-walk from inside work reaches the grader. Flag unless the grader dir is a
  # sibling/unrelated subtree, not an ancestor.
  local gdir; gdir="$(dirname "$agrader")"
  case "$awork/" in
    "$gdir"/*) echo "C0 VIOLATION: grader dir ($gdir) is an ANCESTOR of work_dir ($awork) — reachable by a ../ walk (the sia hole)"; return 2 ;;
  esac
  # VIOLATION 3 — grader is a symlink whose target the agent could swap.
  if [ -L "$grader" ]; then echo "C0 VIOLATION: grader is a symlink ($grader) — target is swappable"; return 2; fi
  return 0
}

# heldout_gate <work_dir> <grader_path> [grader_args...] -> verdict block + rc.
heldout_gate() {
  local work="${1:?work_dir}" grader="${2:?grader_path}"; shift 2
  local min="${GATE_MIN_SCORE:-1.0}" baseline="${GATE_BASELINE:-}" pin="${GATE_PIN_SHA:-}"

  # 1) C0 PRE-FLIGHT — prove the grader is unreachable before trusting any score.
  local pf; if ! pf="$(heldout_preflight "$work" "$grader")"; then
    _hg_emit UNPARSEABLE "STRUCTURAL: $pf" "C0 not guaranteed — refusing to report a score (a verdict here would be greenwash)"
    return 2
  fi

  # 2) C2 CONTENT-ADDRESS — if a hash is pinned, a changed grader is a violation.
  if [ -n "$pin" ]; then
    local got; got="$(_hg_sha "$grader")"
    if [ "$got" != "$pin" ]; then
      _hg_emit UNPARSEABLE "STRUCTURAL: grader sha256 $got != pinned $pin — the evaluator was modified"
      return 2
    fi
  fi

  # 3) RUN THE GRADER from a CLEAN cwd + scrubbed env (E2 hardening: defeats a
  #    poisoned sitecustomize/conftest/pytest shim sitting in work_dir, and any
  #    PYTHON* import-path tricks). The grader is invoked by ABSOLUTE path; cwd=/
  #    so nothing in work_dir is implicitly importable.
  local out rc; out="$( cd / && env -u PYTHONPATH -u PYTHONSTARTUP -u PYTHONHOME \
                        "$(_hg_realpath "$grader")" "$@" 2>&1 )"; rc=$?
  if [ "$rc" -ne 0 ]; then
    _hg_emit FAIL "grader exited $rc (machine-checked reality, not opinion)" \
                  "$(printf '%s' "$out" | tail -5 | tr '\n' ' ')"
    return 1
  fi

  # 4) PARSE the held-out score. The grader's contract: a final "SCORE: <float>".
  local score; score="$(printf '%s\n' "$out" | grep -iE '^[[:space:]]*SCORE:' | tail -1 | sed -E 's/.*:[[:space:]]*//')"
  if ! printf '%s' "$score" | grep -qE '^-?[0-9]+(\.[0-9]+)?$'; then
    _hg_emit UNPARSEABLE "grader did not emit a parseable 'SCORE: <float>' line (got: ${score:-<none>})"
    return 2
  fi

  # 5) THRESHOLD + RATCHET — both enforced here, OUTSIDE the agent's reach.
  local need="$min"
  if [ -n "$baseline" ] && awk "BEGIN{exit !($baseline > $min)}"; then need="$baseline"; fi
  if awk "BEGIN{exit !($score >= $need)}"; then
    _hg_emit PASS "held-out score $score >= threshold $need (grader unreachable, clean cwd, exec-checked)"
    return 0
  else
    _hg_emit FAIL "held-out score $score < threshold $need"
    return 1
  fi
}

# Allow direct CLI use: lib/heldout-gate.sh <work_dir> <grader> [args...]
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  heldout_gate "$@"
fi
