# Orchestrion: Universal Agent Skill Router

A portable agent skill that routes software tasks through Superpowers, gstack, Matt Pocock skills, and llm-council-plus without assuming a specific host agent.

## Files

- `SKILL.md` — the actual portable skill.

## Install

This skill is installed via the canonical `skills-sync` mechanism. It lives in the source-of-truth dir at `~/Documents/workspace/skills-and-personas/new-skills/orchestrion-universal-agent-router/`, gets canonicalized to `~/.agents/skills/orchestrion-universal-agent-router/`, and symlinked into all 41 agent paths declared in `~/dotfiles/scripts/agent-paths.json` (Claude Code, Pi, OpenClaw, Hermes, Codex, Gemini CLI, Cline, Kilo Code, Roo Code, Crush, Cursor, OpenCode, Amp, Augment, Goose, Junie, OpenHands, Windsurf, Zed, etc.).

```bash
skills-sync orchestrion-universal-agent-router
skills-sync --verify orchestrion-universal-agent-router
```

For unknown hosts not in agent-paths.json, paste the contents of `SKILL.md` into `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/rules`, or the host's project instruction file.
