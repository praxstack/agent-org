# Agent skill architecture

Vendored skills form an **AI engineering operating system** — not a flat pile of prompts.
Activate one methodology per task; use `vercel-find-skills` to discover more on demand.

## Pipeline

```
find-skills (discovery)
        ↓
PRODUCT / SPEC — gstack OR Spec Kit OR ce-brainstorm/ce-plan
        ↓
INTERROGATE — shadcn-improve + matt-* (grill, to-spec, triage)
        ↓
IMPLEMENT — pstack + superpowers-* (TDD, plans, subagents)
        ↓
TEST / REVIEW — superpowers + matt-code-review + coderabbit-* + tob-differential-review
        ↓
SECURITY GATE — tob-* (Semgrep, CodeQL, supply-chain, second-opinion)
        ↓
BROWSER QA — browser-agent-browser (after unit/integration tests)
        ↓
SHIP — gstack-ship + ctk-loop-on-ci
        ↓
COMPOUND — ce-compound (knowledge back into repo)
```

## Core 10 (always vendored)

| # | Skill / pack | Role |
|---|--------------|------|
| 1 | `pstack-*` | Cursor-native multi-model reasoning |
| 2 | `superpowers-*` | Disciplined engineering methodology |
| 3 | `matt-*` | Deep interrogation, TDD, architecture |
| 4 | `gstack-*` | Full software-company workflow |
| 5 | `shadcn-improve` | Read-only audit + handoff plans |
| 6 | `tob-*` | Security review gate |
| 7 | `browser-*` | Real-browser verification |
| 8 | `vercel-*` | React/Next.js + web design audit |
| 9 | `vercel-find-skills` | Skill package manager / discovery |
| 10 | `ce-*` | Compound learning loop |

## Native plugins (install in Cursor, not vendored)

These need harness hooks beyond `SKILL.md` files:

```text
/add-plugin pstack          → then /setup-pstack
/add-plugin superpowers
/add-plugin cursor-team-kit
/add-plugin compound-engineering   → EveryInc/compound-engineering-plugin
```

**gstack**: vendored `gstack-*` skills ship in-repo; Cloud Agent bootstrap also runs:

```bash
./scripts/install-native-runtimes.sh cursor
# or: cd gstack && ./setup --host cursor --no-prefix
```

That installs `~/.cursor/skills/gstack/` (`bin/`, `lib/`, browse) and regenerates skill docs. Skill folders stay `gstack-plan-ceo-review` etc.; the `name:` field in each `SKILL.md` is `plan-ceo-review` (use `/plan-ceo-review` or search `gstack-plan-ceo-review`).

## Research & freshness layer (vendored)

| Skill | Role |
|-------|------|
| `last30days` | Trend radar — verify claims independently |
| `research-deep` | Structured multi-source research |
| `vercel-find-skills` | Discover more skills on demand |
| `nvidia-skill-finder` | NVIDIA domain skill catalog |

## CLI / MCP layers (install per project, not vendored)

```bash
# Spec / change management
npm install -g @fission-ai/openspec@latest && openspec init

# Repo architecture graph
uv tool install graphifyy && graphify cursor install --project

# Formal spec kit (greenfield)
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

**Matt Pocock**: pick **either** native `claude plugins install mattpocock-skills` **or** vendored `matt-*` — not both.

## On-demand (per project)

Install when the stack matches — do not vendor everything:

```bash
npx skills@latest add aws/agent-toolkit-for-aws/skills --skill '*' -g -a cursor -y
npx skills@latest add cloudflare/skills --skill '*' -g -a cursor -y
npx skills@latest add supabase/agent-skills --skill '*' -g -a cursor -y
npx skills@latest add microsoft/skills --skill <name> -g -a cursor -y   # selective only
```

**Spec Kit** (formal spec-driven dev):

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init --here --integration cursor-agent
```

**agent-browser CLI** (pairs with `browser-*` skills):

```bash
npm install -g agent-browser && agent-browser install
```

## Refresh

```bash
./scripts/install-skill-packs.sh
```
