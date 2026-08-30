# Autonomous Orchestrion: Council-Swarm Pure Work Protocol

This folder contains a host-neutral `SKILL.md` for advanced autonomous agent work — a council-swarm protocol layered on the base Orchestrion router.

Adds:

- host-neutral discovery
- skill discovery/loading/fallback
- heavy `llm-council-plus` gates
- specialist subagent orchestration
- deep research agents
- red-team agents
- eval/judge-calibration agents
- self-improving-agent workflows
- champion-challenger and Pareto promotion patterns
- verification-first execution
- safety and rollback rails

Includes a skill priority ladder, advanced skill-family router (deep research, red-team, eval/judge design, self-improvement, memory/continuity), council-swarm policy combining subagents with `llm-council-plus`, and standard subagent roles (repo-cartographer, research-scout, architecture-critic, red-team, test-strategist, judge-calibrator, implementer, reviewer, qa-browser, docs-archivist).

Advanced workflows: self-improving-agent, eval and judge design, architecture decision, production change.

## Install

```bash
skills-sync autonomous-orchestrion
skills-sync --verify autonomous-orchestrion
```

## Usage

Invoke for any non-trivial task where the agent should own:

```text
discovery -> planning -> council -> subagents -> execution -> review -> verification -> docs/handoff
```

Do not use it for tiny one-line edits unless the tiny edit has high risk.
