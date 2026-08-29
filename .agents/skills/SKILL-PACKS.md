# Installed skill packs

Vendored by `scripts/install-skill-packs.sh` for Claude Code / Cursor / Agents.

## Packs

| Prefix | Source | Notes |
|--------|--------|-------|
| `gstack-*` | [garrytan/gstack](https://github.com/garrytan/gstack) | Slim unified install: `gstack/` tree (bin, scripts) + prefixed `gstack-*` discovery dirs. No iOS, browse binary, gbrain, heavy design assets |
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
| `tob-*` | [trailofbits/skills](https://github.com/trailofbits/skills) | Full security engineering repo vendored |
| `browser-*` | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | Real-browser QA after tests |
| `ce-*` | [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) | Brainstorm → plan → work → review → compound |
| `gh-*` | [github/awesome-copilot](https://github.com/github/awesome-copilot) | Promoted GitHub/agent workflows (not full 400+ set) |
| `supabase-*` | [supabase/agent-skills](https://github.com/supabase/agent-skills) | Postgres + Supabase engineering |
| `cloudflare-*` | [cloudflare/skills](https://github.com/cloudflare/skills) | Workers, DO, Agents SDK |
| `ms-*` | [microsoft/skills](https://github.com/microsoft/skills) | General dev skills from .github/skills only |
| `aws-*` | [aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) | Core AWS skills cartridge |
| `last30days` | [mvanhorn/last30days-skill](https://github.com/mvanhorn/last30days-skill) | Recency radar (X/Reddit/HN/web) |
| `research-deep` | [24601/agent-deep-research](https://github.com/24601/agent-deep-research) | Structured multi-source research |
| `hallmark` | [Nutlope/hallmark](https://github.com/Nutlope/hallmark) | Anti-slop UI art direction |
| `remotion-*` | [remotion-dev/skills](https://github.com/remotion-dev/skills) | Programmatic video |
| `nvidia-skill-finder` | [NVIDIA/skills](https://github.com/NVIDIA/skills) | NVIDIA skill catalog discovery |

See `SKILL-ARCHITECTURE.md` for the recommended pipeline and native plugin installs.

### Native runtimes (not vendored into repo)

After vendoring, Cloud Agent bootstrap runs `scripts/install-native-runtimes.sh`:

- **gstack**: `./setup --host cursor --no-prefix` → `~/.cursor/skills/gstack/` runtime (`bin/`, `lib/`, browse) plus regenerated `gstack-*` skill docs

### Skipped / slimmed / on-demand CLI

- **gstack**: iOS (`ios-*`), browse binary (`browse`, `open-gstack-browser`, `setup-browser-cookies`), gbrain (`setup-gbrain`, `sync-gbrain`), heavy design (`design-html`, `design-shotgun`, `make-pdf`), benchmarks, scrape, `connect-chrome`, `codex`. Vendored skills use the `gstack-*` prefix (e.g. `gstack-ship`); upstream short names (`ship`, `review`) map to those dirs. The unified `gstack/` directory (with `bin/`, `scripts/`) is installed alongside for runtime helpers — not listed in INDEX.txt.
- **awesome-copilot**: 400+ total; only general dev workflows vendored (gh-*)
- **anthropics/skills**: creative/office-only packs (pdf, pptx, algorithmic-art)
- **microsoft/skills**: 175+ Azure SDK plugins skipped; only .github/skills vendored (ms-*)
- **aws**: only core-skills cartridge; specialized skills on demand
- **vercel**: react-native-skills skipped
- **spec-kit**: CLI — `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`
- **openspec**: CLI — `npm install -g @fission-ai/openspec@latest` then `openspec init`
- **graphify**: CLI/MCP — `uv tool install graphifyy` then `graphify cursor install`
- **impeccable**: `npx impeccable skills install` (design iteration; install per frontend project)
- **NVIDIA domain skills**: use `nvidia-skill-finder` or `npx skills add nvidia/skills --skill <name>`

## Paths

Same skill trees are mirrored to:

- `.claude/skills/` (Claude Code)
- `.agents/skills/` (conventional Agents path)
- `.agnets/skills/` (requested spelling)

## Refresh

```bash
./scripts/install-skill-packs.sh
```

Also syncs into `~/.claude/skills`, `~/.cursor/skills`, and `~/.agents/skills` for Cloud Agent / global discovery. The `gstack/` infrastructure tree is included in those mirrors (except Cursor `gstack*` paths, which native setup owns).
