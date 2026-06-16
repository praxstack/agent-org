#!/usr/bin/env bash
# block-commit.sh — PreToolUse hook that makes the CODER agent physically unable
# to commit. This is the "gate": the coder produces a diff and STOPS; it cannot
# advance past the gate on its own. The reviewer (a different session/model)
# inspects the diff and decides whether to lift the gate.
#
# Wire it in the coder's settings.json:
#   "hooks": { "PreToolUse": [ {
#       "matcher": "Bash",
#       "hooks": [ { "type": "command",
#                    "command": "/absolute/path/to/agent-org/hooks/block-commit.sh" } ]
#   } ] }
#
# Contract (Claude Code PreToolUse hooks): the hook receives the tool call as
# JSON on stdin. Exit 2 = BLOCK the tool call; stderr is fed back to the agent
# as the block reason. Exit 0 = allow. We block ONLY `git commit` (and pushes),
# so the coder can still run tests, git status, git diff, etc.

set -uo pipefail

input="$(cat)"

# Extract the command being run. Prefer jq; fall back to grep so the hook works
# even if jq is absent (it models the real contract either way).
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  cmd="$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"(.*)"/\1/')"
fi

# Gate condition: block commits and pushes. The coder must hand the diff to the
# reviewer instead of self-committing.
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
  echo "GATE: commits are blocked for the coder agent. Do NOT commit." >&2
  echo "Stage your changes (git add -A) and STOP. Output a summary of the diff." >&2
  echo "The reviewer agent will inspect the staged diff and either request changes" >&2
  echo "or lift the gate. You cannot commit yourself." >&2
  exit 2   # exit 2 = block the tool call, feed stderr back to the agent
fi

exit 0   # everything else (tests, status, diff, reads) is allowed
