#!/usr/bin/env bash
# lib/verdict.sh — canonical cross-runner verdict contract.
#
# WHY: leaves come from heterogeneous runners. A claude leaf is JSON-wrapped
# ({"result": "...the text..."}); a hermes -z leaf is RAW text. A chair that
# wants to synthesize votes from both must see ONE shape, not two. This lib is
# the normalizer: (raw runner output) -> {VERDICT, VOICE, FINDINGS}, tolerant of
# casing, JSON-wrapping, and a missing VERDICT line (which is itself a signal).
#
# Contract (the canonical block every voice is asked to emit):
#   VOICE: <lens>
#   VERDICT: PASS | FAIL
#   FINDINGS:
#   - <concrete issue>            (may be empty on PASS)
#
# Sourced by fanout.sh (and usable by review-loop.sh). No hard jq dependency for
# reading: jq is used to peel the claude JSON wrapper if present, else a sed
# fallback keeps it portable.
set -uo pipefail

# verdict_unwrap <leaf-file>
# Peel a runner's transport envelope so we get the model's actual TEXT.
#   - claude --output-format json  -> {"result": "...", ...}  -> .result
#   - hermes -z                    -> raw text (no envelope)   -> as-is
# Detection is by content (leading '{' + a "result" key), not by config, so a
# leaf file is self-describing — you can normalize one without knowing its runner.
verdict_unwrap() {
  local f="${1:?leaf file}" first
  [ -f "$f" ] || { printf ''; return 0; }
  first="$(head -c 1 "$f" 2>/dev/null)"
  if [ "$first" = "{" ] && grep -q '"result"' "$f" 2>/dev/null; then
    if command -v jq >/dev/null 2>&1; then
      jq -r '.result // .text // empty' "$f" 2>/dev/null
    else
      # crude but portable: pull the "result" string value
      sed -nE 's/.*"result"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' "$f" 2>/dev/null \
        | sed -E 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g'
    fi
  else
    cat "$f" 2>/dev/null
  fi
}

# verdict_field <field> <text>
# Extract a canonical field from already-unwrapped text. Case-insensitive on the
# key; returns the trimmed value. VERDICT is further normalized to PASS|FAIL|"".
verdict_field() {
  local field="$1" text="$2" line val
  line="$(printf '%s\n' "$text" | grep -iE "^[[:space:]]*${field}:" | head -1)"
  val="$(printf '%s' "$line" | sed -E "s/^[[:space:]]*[A-Za-z_]+:[[:space:]]*//")"
  printf '%s' "$val"
}

# verdict_normalize <leaf-file>
# The public entry point. Emits one canonical block to stdout:
#   VOICE: <voice or "unknown">
#   VERDICT: PASS | FAIL | UNPARSEABLE
#   FINDINGS:
#   <verbatim findings tail, or "- (none)">
# UNPARSEABLE is a first-class outcome (PR-2.2 spirit): a leaf that didn't follow
# the contract is a FAIL-grade signal, never silently treated as PASS.
verdict_normalize() {
  local f="${1:?leaf file}" text raw_verdict voice findings v
  text="$(verdict_unwrap "$f")"
  if [ -z "$text" ]; then
    printf 'VOICE: unknown\nVERDICT: UNPARSEABLE\nFINDINGS:\n- empty leaf (no output captured)\n'
    return 0
  fi
  raw_verdict="$(verdict_field VERDICT "$text")"
  voice="$(verdict_field VOICE "$text")"; [ -z "$voice" ] && voice=unknown
  # normalize verdict token — FAIL-CLOSED: FAIL is checked first, so a mixed or
  # hedged verdict ("FAIL — tests did not pass") can never normalize to PASS.
  case "$(printf '%s' "$raw_verdict" | tr '[:lower:]' '[:upper:]')" in
    *FAIL*) v=FAIL ;;
    *PASS*) v=PASS ;;
    *)      v=UNPARSEABLE ;;
  esac
  # findings = everything after a FINDINGS: line, else any CHANGES_REQUIRED: tail
  findings="$(printf '%s\n' "$text" | awk 'BEGIN{p=0} /^[[:space:]]*(FINDINGS|CHANGES_REQUIRED):/{p=1;next} p{print}' | sed '/^[[:space:]]*$/d')"
  [ -z "$findings" ] && findings="- (none)"
  printf 'VOICE: %s\nVERDICT: %s\nFINDINGS:\n%s\n' "$voice" "$v" "$findings"
}

# verdict_token <leaf-file> — just the normalized PASS|FAIL|UNPARSEABLE token.
verdict_token() { verdict_normalize "$1" | grep -m1 '^VERDICT:' | awk '{print $2}'; }

# verdict_aggregate <leaf-file...> — strict council rule: PASS iff EVERY leaf is
# PASS. Any FAIL or UNPARSEABLE -> FAIL. Zero leaves -> FAIL (an empty council
# never passes work — fail-closed). Echoes the consolidated verdict token.
verdict_aggregate() {
  [ "$#" -eq 0 ] && { printf 'FAIL'; return; }
  local f tok overall=PASS
  for f in "$@"; do
    tok="$(verdict_token "$f")"
    [ "$tok" = "PASS" ] || overall=FAIL
  done
  printf '%s' "$overall"
}
