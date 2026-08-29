# Installed skill packs

Vendored by `scripts/install-skill-packs.sh` for Claude Code / Cursor / Agents.

## Packs

| Prefix | Source | Notes |
|--------|--------|-------|
| `gstack-*` | [garrytan/gstack](https://github.com/garrytan/gstack) | Slimmed: no iOS, browse binary, gbrain, heavy design assets |
| `pstack-*` | [cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack) via [backnotprop/pstack](https://github.com/backnotprop/pstack) | Full workflow + principles |
| `matt-*` | [mattpocock/skills](https://github.com/mattpocock/skills) | Full set (excludes deprecated/in-progress) |
| `superpowers-*` | [obra/superpowers](https://github.com/obra/superpowers) | Full core methodology set |
| `ctk-*` | [cursor/plugins/cursor-team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit) | PR/CI/deslop/control-cli |
| `ralph-loop*` | [cursor/plugins/ralph-loop](https://github.com/cursor/plugins/tree/main/ralph-loop) | Iterative autonomous loops |
| `cursor-*` | orchestrate, continual-learning, cli-for-agent, teaching, create-plugin, agent-compatibility | Multi-agent / CLI / plugin authoring |
| `shadcn-improve` | [shadcn/improve](https://github.com/shadcn/improve) | Read-only codebase audit + handoff plans |
| `coderabbit-*` | [coderabbitai/skills](https://github.com/coderabbitai/skills) | PR review + autofix workflows |
| `vercel-*` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills), [find-skills](https://github.com/vercel-labs/skills) | React/web/deploy + skill discovery |
| `anthropic-*` | [anthropics/skills](https://github.com/anthropics/skills) | Slim dev set: MCP, testing, skill authoring |
| `tob-*` | [trailofbits/skills](https://github.com/trailofbits/skills) | Security gate: diff review, CodeQL/Semgrep, supply chain |
| `browser-*` | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | Real-browser QA after tests |
| `ce-*` | [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) | Brainstorm → plan → work → review → compound |
| `gh-*` | [github/awesome-copilot](https://github.com/github/awesome-copilot) | Promoted GitHub/agent workflows (not full 400+ set) |
| `supabase-*` | [supabase/agent-skills](https://github.com/supabase/agent-skills) | Postgres + Supabase engineering |
| `cloudflare-*` | [cloudflare/skills](https://github.com/cloudflare/skills) | Workers, DO, Agents SDK |
| `ms-*` | [microsoft/skills](https://github.com/microsoft/skills) | General dev skills from .github/skills only |
| `aws-*` | [aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) | Core AWS skills cartridge |

See `SKILL-ARCHITECTURE.md` for the recommended pipeline and native plugin installs.

### Skipped / slimmed

- **gstack**: iOS, browse binary, gbrain, heavy design assets
- **trailofbits**: 80+ total; only promoted security gate set vendored
- **awesome-copilot**: 400+ total; only general dev workflows vendored
- **anthropics/skills**: creative/office-only packs (pdf, pptx, algorithmic-art)
- **microsoft/skills**: too large — use `vercel-find-skills` + `npx skills add` on demand
- **spec-kit**: CLI tool, not SKILL.md — install via `uv tool install specify-cli`
- **Stack-specific** (install per project): aws/agent-toolkit-for-aws, cloudflare/skills, supabase/agent-skills

## Paths

Same skill trees are mirrored to:

- `.claude/skills/` (Claude Code)
- `.agents/skills/` (conventional Agents path)
- `.agnets/skills/` (requested spelling)

## Refresh

```bash
./scripts/install-skill-packs.sh
```

Also syncs into `~/.claude/skills`, `~/.cursor/skills`, and `~/.agents/skills` for Cloud Agent / global discovery.
