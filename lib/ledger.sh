#!/usr/bin/env bash
# lib/ledger.sh — v2 Run Ledger. The single append-only source of truth for a run.
# Externalize state BEFORE adding scope (architecture conviction #1): every handoff
# is a recorded FACT, not an in-memory accident. Sourced by fanout.sh / review-loop.
#
# One JSON line per event. Schema (PRD §v2):
#   {ts, run_id, phase, actor, model, event, input_hash, output_hash, gate_result, extra}
# No jq dependency for WRITING (hand-built JSON, values escaped); jq used for reading
# if present, with a grep fallback so the ledger is portable.
set -uo pipefail

LEDGER_FILE="${LEDGER_FILE:-${AGENT_ORG_RUNS:-/tmp}/ledger.jsonl}"

_ldg_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "0"; }
_ldg_hash() { # stdin or $1 -> short sha (content-addressed; enables replay/dedup)
  local h
  if [ $# -gt 0 ]; then h="$(printf '%s' "$1" | shasum -a 256 2>/dev/null)"; else h="$(shasum -a 256 2>/dev/null)"; fi
  printf '%s' "${h%% *}" | cut -c1-12
}
_ldg_esc() { # minimal JSON string escape (backslash, quote, newline, tab, CR)
  local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# ledger_init <run_id> [file]
ledger_init() {
  LEDGER_RUN_ID="${1:?run_id}"; [ $# -ge 2 ] && LEDGER_FILE="$2"
  mkdir -p "$(dirname "$LEDGER_FILE")"
  : > "$LEDGER_FILE"   # fresh file per run (append-only WITHIN a run)
  ledger_event init driver "" start "" "" ""
}

# ledger_event <phase> <actor> <model> <event> <input> <output> <gate_result>
# input/output are hashed (content-addressed), never stored raw (keeps the ledger lean —
# and per E0, lean context is the cost lever). Returns the appended JSON line.
ledger_event() {
  local phase="$1" actor="$2" model="$3" event="$4" input="$5" output="$6" gate="$7"
  local ih oh; ih="$( [ -n "$input" ] && _ldg_hash "$input" || echo "" )"; oh="$( [ -n "$output" ] && _ldg_hash "$output" || echo "" )"
  printf '{"ts":"%s","run_id":"%s","phase":"%s","actor":"%s","model":"%s","event":"%s","input_hash":"%s","output_hash":"%s","gate_result":"%s"}\n' \
    "$(_ldg_now)" "$(_ldg_esc "${LEDGER_RUN_ID:-?}")" "$(_ldg_esc "$phase")" "$(_ldg_esc "$actor")" "$(_ldg_esc "$model")" \
    "$(_ldg_esc "$event")" "$ih" "$oh" "$(_ldg_esc "$gate")" >> "$LEDGER_FILE"
}

# ledger_field <event-substr> <json-key> — read a field (jq if present, else grep)
ledger_count() { grep -c "\"event\":\"$1\"" "$LEDGER_FILE" 2>/dev/null || echo 0; }

# ledger_replay_verdict — deterministically reconstruct the final verdict from the
# ledger alone (PR-2.3): PASS iff a 'gate' event recorded gate_result=PASS and no
# later FAIL. Reads only the file, never re-runs anything.
ledger_replay_verdict() {
  local last=""
  while IFS= read -r line; do
    case "$line" in *'"event":"gate"'*)
      case "$line" in *'"gate_result":"PASS"'*) last=PASS ;; *'"gate_result":"FAIL"'*) last=FAIL ;; esac ;;
    esac
  done < "$LEDGER_FILE"
  printf '%s' "${last:-NONE}"
}
