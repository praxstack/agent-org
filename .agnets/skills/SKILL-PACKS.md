# Installed skill packs

Vendored by `scripts/install-skill-packs.sh` for Claude Code / Cursor / Agents.

## Packs

| Prefix | Source | Notes |
|--------|--------|-------|
| `gstack-*` | [garrytan/gstack](https://github.com/garrytan/gstack) | Slimmed: no iOS, browse binary, gbrain, heavy design assets |
| `pstack-*` | [cursor/plugins/pstack](https://github.com/cursor/plugins/tree/main/pstack) via [backnotprop/pstack](https://github.com/backnotprop/pstack) | Full workflow + principles |
| `matt-*` | [mattpocock/skills](https://github.com/mattpocock/skills) | Promoted engineering + productivity set |
| `superpowers-*` | [obra/superpowers](https://github.com/obra/superpowers) | Full core methodology set |
| `ctk-*` | [cursor/plugins/cursor-team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit) | PR/CI/deslop/control-cli |
| `ralph-loop*` | [cursor/plugins/ralph-loop](https://github.com/cursor/plugins/tree/main/ralph-loop) | Iterative autonomous loops |
| `cursor-*` | orchestrate, continual-learning, cli-for-agent | Multi-agent / CLI extras |

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
