# agent-org

A tiny, dependency-light **reviewer↔coder gated loop** for autonomous coding with [Claude Code](https://docs.claude.com/en/docs/claude-code). One command runs a coder agent that *physically cannot commit*, a deterministic verification gate that runs your real build/tests itself (so an LLM can't fake "it passes"), and an optional multi-voice review council — looping until the work genuinely passes, then committing.

It replaces babysitting two chat windows. You start it and walk away.

```bash
./review-loop.sh "add input validation to the login endpoint" /path/to/repo
```

## Why

The one multi-agent pattern that reliably ships (per both Anthropic's and Cognition's 2026 write-ups) is a **coder gated by a separate reviewer, with single-threaded writes**. `agent-org` is the minimal, honest implementation of exactly that — no framework, no daemon, just bash + the `claude` CLI.

The design is deliberately shaped around the documented failure modes of multi-agent systems:

- **Tree, not mesh** — the driver talks to the coder and the reviewer; the agents never talk to each other (no cycles, no talking-past).
- **Contracts, not histories** — the coder receives the reviewer's *structured verdict*, not a whole transcript (avoids context-loss across handoffs).
- **Single-threaded writes** — only the driver commits, and only after a PASS.
- **Hard exit** — a `MAX_ROUNDS` circuit breaker, so no runaway loops.
- **Unfakeable verification** — the gate runs *your* real command (`go test`, `pytest`, a build, a behavioral check). An LLM cannot lie its way past a failing test.

## How it works

```
you ──▶ review-loop.sh "task" /repo
            │
            ▼   (the script plays both roles via headless `claude -p` calls)
  ┌────────┐  diff   ┌──────────────────┐  if green  ┌──────────────┐
  │ CODER  │────────▶│ DETERMINISTIC    │───────────▶│ COUNCIL      │
  │ gated: │         │ GATE (VERIFY_CMD)│            │ (optional)   │
  │ can't  │◀── fix ─│ run by the script│            │ 3 voices +   │
  │ commit │  the    │ — unfakeable     │◀── FAIL ───│ chairman     │
  └────────┘  real   └──────────────────┘            └──────┬───────┘
       ▲      error                                         │
       └─────────────── loop until PASS ◀───────────────────┘
                              │ PASS
                              ▼
                    driver commits (single write)
```

1. **Coder** implements the task but is blocked from committing by a `PreToolUse` hook (`hooks/block-commit.sh`). It stages a diff and stops.
2. **Deterministic gate** (optional, via `VERIFY_CMD`): the *script* runs your real check. Non-zero exit auto-fails the round and feeds the real output back to the coder — no LLM call needed to catch a broken build.
3. **Council** (optional, via `COUNCIL=1`): three independent specialist voices — correctness, simplicity, security — judge the diff in parallel, blind to each other; a chairman synthesizes one verdict. PASS only if all three pass.
4. **Loop**: on FAIL the coder is resumed with the verdict and tries again, up to `MAX_ROUNDS`. On PASS the driver commits.
5. **Human gate**: if the task is genuinely ambiguous, the coder emits `NEEDS_HUMAN: <question>` and the loop pauses for you instead of guessing.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (`claude` on your `PATH`)
- `bash`, `git`
- `jq` (optional — used to parse session IDs; the loop degrades gracefully without it)

## Install

```bash
git clone https://github.com/<you>/agent-org.git
cd agent-org
chmod +x review-loop.sh hooks/block-commit.sh
```

No build step. The scripts self-locate, so they work from wherever you clone them.

## Usage

**Everyday (single reviewer, cheap):**
```bash
./review-loop.sh "your task" /path/to/repo
```

**High-stakes (3-voice council):**
```bash
COUNCIL=1 REVIEWER_MODEL=opus ./review-loop.sh "task" /repo
```

**Fully hands-off with a real verification gate:**
```bash
COUNCIL=1 MAX_ROUNDS=5 \
VERIFY_CMD='make build && go test ./... && ./run-e2e.sh' \
  ./review-loop.sh "implement feature X with tests" /repo
```

**Human-gate resume (when the coder asks `NEEDS_HUMAN`):**
```bash
HUMAN_ANSWER="use Postgres, not SQLite" CODER_SID=<printed-id> \
  ./review-loop.sh --resume-human <RUN_DIR> "<task>" /repo
```

### Environment variables

| Var | Default | Meaning |
|---|---|---|
| `CODER_MODEL` | `sonnet` | the implementer model |
| `REVIEWER_MODEL` | `opus` | the (different, stronger) reviewer/council model |
| `MAX_ROUNDS` | `5` | circuit breaker — max coder↔review cycles |
| `COUNCIL` | `0` | `1` = 3-voice council (correctness/simplicity/security) instead of one reviewer |
| `VERIFY_CMD` | *(empty)* | a shell command the script runs to verify each round; non-zero auto-fails |
| `CLAUDE_BIN` | resolved from `PATH` | override the `claude` binary path |
| `BLOCK_COMMIT_HOOK` | `./hooks/block-commit.sh` | override the gate hook path |
| `AGENT_ORG_RUNS` | `./runs` | where per-run state (prompts, diffs, verdicts) is written |

## Run artifacts

Each run writes a durable trail to `runs/run-<pid>/`: the prompts sent, the staged diffs per round, the verdicts, the council voices, and the verify logs. Useful for auditing what actually happened.

## The honest boundaries

- **Two interactive Claude chat windows cannot talk to each other** — there's no IPC between them. This loop sidesteps that by replacing chat windows with headless `claude -p` calls a script chains together.
- **The gate is only as good as your `VERIFY_CMD`.** Give it a real check (build + tests + a behavioral/e2e step). Without one, the council judges code that was never actually run.
- This is the **proven leaf unit** of a larger vision (a CEO→departments agent org). It's deliberately small. For durable, crash-survivable gates at scale, the natural next step is [LangGraph](https://github.com/langchain-ai/langgraph) (interrupt + checkpointer) or [Temporal](https://temporal.io) (child workflows). This repo is the thing you compose *up from*.

## Examples

`examples/tmux-drive-example.sh` shows a **behavioral** `VERIFY_CMD` — driving a TUI binary in tmux and grepping the rendered panes — so the gate verifies real runtime behavior, not just unit tests.

## License

MIT — see [LICENSE](LICENSE).
