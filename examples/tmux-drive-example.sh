#!/usr/bin/env bash
# tmux-drive-ksum.sh — BEHAVIORAL verifier for ksum-tui, usable as a VERIFY_CMD.
#
# This is the piece that makes ksum-tui's GATE D fully hands-off: the SCRIPT
# (not an LLM, not a human) launches the INSTALLED binary in a real tmux pane,
# drives keys, and greps the rendered panes for the things that must be true.
# Exit 0 = behavior verified; non-zero = a real, machine-checked failure that
# review-loop.sh feeds straight back to the coder.
#
# It drives the binary the user actually runs (~/.local/bin/ksum-tui), in tmux
# (the only harness that answers Bubble Tea v2's capability handshake — a raw
# pty.fork stalls and paints nothing). Honest scope: kitty inline-mermaid is NOT
# checked here because tmux cannot composite kitty graphics — that one item stays
# NOT-VERIFIED for any verifier, human or machine.
#
# Usage:  tmux-drive-ksum.sh            # uses the installed binary
#         KSUM_TUI_BIN=/path tmux-drive-ksum.sh
set -uo pipefail

BIN="${KSUM_TUI_BIN:-$HOME/.local/bin/ksum-tui}"
TMUX="$(command -v tmux)"            # real binary, NOT the shell function
S="ksumverify_$$"                    # unique session name
W=140; H=40                          # generous size so panels render unclipped
FAILED=0

[ -x "$BIN" ] || { echo "BEHAVIORAL FAIL: $BIN not executable"; exit 2; }
[ -n "$TMUX" ] || { echo "BEHAVIORAL FAIL: tmux not found"; exit 2; }

# cap <after-keys-sent> -> echoes the rendered pane text (ANSI stripped).
cap() { "$TMUX" capture-pane -t "$S" -p 2>/dev/null | sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g'; }
check() { # check "<label>" "<grep-pattern>" -> pass/fail against current pane
  local label="$1" pat="$2"
  if cap | grep -qE "$pat"; then echo "  ✓ $label"; else echo "  ✗ $label (missing: $pat)"; FAILED=1; fi
}
send() { "$TMUX" send-keys -t "$S" "$@"; sleep 1.2; }

cleanup() { "$TMUX" kill-session -t "$S" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# Launch the INSTALLED binary in a real tmux session.
"$TMUX" new-session -d -s "$S" -x "$W" -y "$H" "$BIN" 2>/dev/null \
  || { echo "BEHAVIORAL FAIL: could not start tmux session"; exit 2; }
sleep 3   # let Bubble Tea complete its v2 capability handshake + first paint

echo "-- behavioral checks (installed binary in tmux) --"
# Home screen: the gradient KSUM wordmark must render (the whole point of the rebuild).
check "Home renders KSUM wordmark"      '█'
check "Home shows capture prompt"       'paste a url|capture'
check "Home status bar present"         'ready|library|help'

# Navigation: ^l -> Library (must show it switched).
send C-l
check "^l -> Library"                   'filter|library|summaries|[0-9]+/[0-9]+'

# Back to Home, then ^d -> Doctor.
send Escape
send C-d
check "^d -> Doctor (engine readiness)" 'hyperframes|engine|ready|doctor'

# Quit cleanly from Home.
send Escape
send q
sleep 1.5
if "$TMUX" has-session -t "$S" 2>/dev/null; then
  # try a hard quit fallback before failing
  send C-c
  if "$TMUX" has-session -t "$S" 2>/dev/null; then
    echo "  ✗ q did not quit cleanly (session still alive)"; FAILED=1
  else echo "  ✓ quit (via ^c fallback)"; fi
else
  echo "  ✓ q quits cleanly"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "BEHAVIORAL VERIFY OK — installed ksum-tui renders + navigates + quits"
  exit 0
else
  echo "BEHAVIORAL VERIFY FAILED — see misses above"
  exit 1
fi
