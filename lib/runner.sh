#!/usr/bin/env bash
# lib/runner.sh — the cross-runner dispatch layer for agent-org.
#
# WHY THIS EXISTS (v-ladder expansion): every script above v2 (the review loop,
# departments, the CEO) needs to spawn a leaf agent without caring WHICH agent
# CLI backs it. This is that seam. A leaf is named by a single "model token";
# the token's prefix selects the runner, the rest is the model. One function,
# `run_agent`, turns (token, prompt-file, out-file) into captured RAW TEXT —
# transport-unwrapped, ready for lib/verdict.sh to normalize.
#
# Supported tokens (proven headless 2026-06-19):
#   <model>                         -> claude  -p <prompt> --model <model> --output-format json   (jq .result)
#   claude:<model>                  -> same, explicit
#   hermes[:<model>]                -> hermes  -z <prompt> [-m <model>] --yolo                     (raw)
#   pi[:<model>]                    -> pi      -p <prompt> [--model <model>] --mode text           (raw, OSC-stripped)
#   opencode:<provider/model>       -> opencode run <prompt> [-m <model>] --format json            (jq-ish)
#   codex[:<model>]                 -> codex   exec --skip-git-repo-check [-c model=<model>] <prompt>  (last lines)
#
# The DEFAULT (bare token, no known prefix) is claude — preserves every existing
# caller (review-loop.sh, fanout.sh) byte-for-byte.
set -uo pipefail

# Several of these CLIs are shadowed by `yolo` shell FUNCTIONS in the user's
# interactive shell; `command -v` would return the function, not a path. Resolve
# the REAL binary by taking the first PATH hit that is an absolute path (functions
# don't start with '/'), with a known fallback. type -P would also work but is
# bash-specific; this is portable.
_resolve_bin() { # name fallback
  local p; p="$(command -v "$1" 2>/dev/null | grep '^/' | head -1)"
  [ -n "$p" ] && { printf '%s' "$p"; return; }
  printf '%s' "$2"
}
CLAUDE_BIN="${CLAUDE_BIN:-$(_resolve_bin claude "$HOME/.local/bin/claude")}"
HERMES_BIN="${HERMES_BIN:-$(_resolve_bin hermes hermes)}"
PI_BIN="${PI_BIN:-$(_resolve_bin pi pi)}"
OPENCODE_BIN="${OPENCODE_BIN:-$(_resolve_bin opencode /opt/homebrew/bin/opencode)}"
CODEX_BIN="${CODEX_BIN:-$(_resolve_bin codex /opt/homebrew/bin/codex)}"

# _strip_osc — drop terminal OSC escape sequences (pi emits 777;notify on exit).
_strip_osc() { sed -E $'s/\x1b\\][0-9;]*;[^\x07]*\x07//g; s/\x1b\\[[0-9;]*[A-Za-z]//g'; }

# runner_of <token> -> the runner name (for logging/ledger).
runner_of() {
  case "$1" in
    hermes|hermes:*) echo hermes ;;
    pi|pi:*)         echo pi ;;
    opencode:*)      echo opencode ;;
    codex|codex:*)   echo codex ;;
    claude:*)        echo claude ;;
    *)               echo claude ;;
  esac
}

# run_agent <token> <prompt-file> <out-file>
# Runs the leaf, writes the runner's native output to <out-file>.raw (for audit),
# and the UNWRAPPED result text to <out-file>. Never aborts the caller (|| true);
# an empty result is a signal lib/verdict.sh turns into UNPARSEABLE.
run_agent() {
  local token="$1" pf="$2" out="$3"; local prompt; prompt="$(cat "$pf")"
  local model="${token#*:}"; [ "$model" = "$token" ] && model=""   # bare token -> no explicit model
  case "$token" in
    hermes|hermes:*)
      if [ -n "$model" ]; then "$HERMES_BIN" -z "$prompt" -m "$model" --yolo > "$out.raw" 2>"$out.err" || true
      else "$HERMES_BIN" -z "$prompt" --yolo > "$out.raw" 2>"$out.err" || true; fi
      cat "$out.raw" > "$out" ;;
    pi|pi:*)
      if [ -n "$model" ]; then "$PI_BIN" -p "$prompt" --model "$model" --mode text > "$out.raw" 2>"$out.err" || true
      else "$PI_BIN" -p "$prompt" --mode text > "$out.raw" 2>"$out.err" || true; fi
      _strip_osc < "$out.raw" > "$out" ;;
    opencode:*)
      "$OPENCODE_BIN" run "$prompt" -m "$model" > "$out.raw" 2>"$out.err" || true
      _strip_osc < "$out.raw" > "$out" ;;
    codex|codex:*)
      # codex is chatty; -c model= overrides model. Capture stdout; result text is
      # the agent's message (codex prints it plainly). We keep it all and let the
      # verdict normalizer pick the canonical lines out.
      if [ -n "$model" ]; then "$CODEX_BIN" exec --skip-git-repo-check -c model="$model" "$prompt" > "$out.raw" 2>"$out.err" || true
      else "$CODEX_BIN" exec --skip-git-repo-check "$prompt" > "$out.raw" 2>"$out.err" || true; fi
      _strip_osc < "$out.raw" > "$out" ;;
    claude:*|*)
      "$CLAUDE_BIN" -p "$prompt" --model "${model:-$token}" --output-format json \
          --permission-mode plan > "$out.raw" 2>"$out.err" || true
      if command -v jq >/dev/null 2>&1; then jq -r '.result // .text // empty' "$out.raw" 2>/dev/null > "$out"
      else cat "$out.raw" > "$out"; fi ;;
  esac
  [ -s "$out" ] || printf '' > "$out"
}
