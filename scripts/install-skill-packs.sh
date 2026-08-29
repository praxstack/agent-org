#!/usr/bin/env bash
# install-skill-packs.sh — vendor agent skill packs into this repo + home dirs.
# Idempotent. Safe for Cloud Agent install scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${SKILL_PACK_CACHE:-/tmp/skill-packs}"
HOME_CLAUDE="${HOME}/.claude/skills"
HOME_CURSOR="${HOME}/.cursor/skills"
HOME_AGENTS="${HOME}/.agents/skills"

# Repo targets (user asked for .agnets + conventional .agents)
REPO_TARGETS=(
  "${ROOT}/.claude/skills"
  "${ROOT}/.agents/skills"
  "${ROOT}/.agnets/skills"
)

log() { printf '[skill-packs] %s\n' "$*"; }

# Tracks every skill name installed in this run (for INDEX + prune).
INSTALLED_SKILLS=()

record_skill() {
  INSTALLED_SKILLS+=("$1")
}

need_git_clone() {
  local url="$1" dest="$2"
  if [[ -d "${dest}/.git" ]]; then
    if ! git -C "$dest" fetch --depth 1 origin HEAD; then
      log "WARN: fetch failed for ${dest}; re-cloning"
      rm -rf "$dest"
      git clone --depth 1 --single-branch "$url" "$dest"
      return
    fi
    git -C "$dest" reset --hard FETCH_HEAD
  else
    rm -rf "$dest"
    git clone --depth 1 --single-branch "$url" "$dest"
  fi
}

copy_skill_dir() {
  # copy_skill_dir <src_dir> <dest_name>
  local src="$1" name="$2"
  local skill_md="${src}/SKILL.md"
  [[ -f "$skill_md" ]] || return 0
  for dest_root in "${REPO_TARGETS[@]}" "$HOME_CLAUDE" "$HOME_CURSOR" "$HOME_AGENTS"; do
    mkdir -p "${dest_root}/${name}"
    # Copy skill markdown + small supporting files; skip heavy/binaries
    rsync -a --delete \
      --exclude '.git' \
      --exclude 'node_modules' \
      --exclude 'dist' \
      --exclude '__tests__' \
      --exclude '*.binary' \
      --exclude '*.dylib' \
      --exclude '*.so' \
      --exclude '*.png' \
      --exclude '*.jpg' \
      --exclude '*.gif' \
      --exclude '*.mp4' \
      --exclude '*.wasm' \
      --exclude 'package-lock.json' \
      --exclude 'bun.lock' \
      --exclude 'bun.lockb' \
      "${src}/" "${dest_root}/${name}/"
  done
  record_skill "$name"
}

ensure_cache() {
  mkdir -p "$CACHE"
  log "Refreshing skill pack sources in ${CACHE}"
  need_git_clone https://github.com/garrytan/gstack.git "${CACHE}/gstack"
  need_git_clone https://github.com/obra/superpowers.git "${CACHE}/superpowers"
  need_git_clone https://github.com/mattpocock/skills.git "${CACHE}/mattpocock-skills"
  need_git_clone https://github.com/backnotprop/pstack.git "${CACHE}/pstack"
  need_git_clone https://github.com/cursor/plugins.git "${CACHE}/cursor-plugins"
  need_git_clone https://github.com/shadcn/improve.git "${CACHE}/shadcn-improve"
  need_git_clone https://github.com/coderabbitai/skills.git "${CACHE}/coderabbit-skills"
  need_git_clone https://github.com/vercel-labs/agent-skills.git "${CACHE}/vercel-agent-skills"
  need_git_clone https://github.com/anthropics/skills.git "${CACHE}/anthropic-skills"
  need_git_clone https://github.com/vercel-labs/skills.git "${CACHE}/vercel-skills"
  need_git_clone https://github.com/trailofbits/skills.git "${CACHE}/trailofbits"
  need_git_clone https://github.com/vercel-labs/agent-browser.git "${CACHE}/agent-browser"
  need_git_clone https://github.com/EveryInc/compound-engineering-plugin.git "${CACHE}/compound-engineering"
  need_git_clone https://github.com/github/awesome-copilot.git "${CACHE}/awesome-copilot"
  need_git_clone https://github.com/supabase/agent-skills.git "${CACHE}/supabase-skills"
  need_git_clone https://github.com/cloudflare/skills.git "${CACHE}/cloudflare-skills"
  need_git_clone https://github.com/microsoft/skills.git "${CACHE}/microsoft-skills"
  need_git_clone https://github.com/aws/agent-toolkit-for-aws.git "${CACHE}/aws-toolkit"
  need_git_clone https://github.com/mvanhorn/last30days-skill.git "${CACHE}/last30days"
  need_git_clone https://github.com/24601/agent-deep-research.git "${CACHE}/agent-deep-research"
  need_git_clone https://github.com/Nutlope/hallmark.git "${CACHE}/hallmark"
  need_git_clone https://github.com/remotion-dev/skills.git "${CACHE}/remotion-skills"
  need_git_clone https://github.com/NVIDIA/skills.git "${CACHE}/nvidia-skills"
}

install_gstack_slim() {
  # Slim: skip iOS, browse binary toolchain, heavy design assets, gbrain sync
  local d base
  for d in "${CACHE}/gstack"/*; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    [[ -f "${d}/SKILL.md" ]] || continue
    case "$base" in
      ios-*|browse|open-gstack-browser|setup-browser-cookies|setup-gbrain|sync-gbrain|make-pdf|design-html|design-shotgun|benchmark|benchmark-models|scrape|extension|contrib|docs|bin|agents|claude|codex|gstack|browser-skills|connect-chrome)
        log "gstack skip: $base"
        continue
        ;;
    esac
    copy_skill_dir "$d" "gstack-${base}"
  done
}

install_superpowers() {
  local d
  for d in "${CACHE}/superpowers/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "superpowers-$(basename "$d")"
  done
}

install_matt_pocock() {
  # Full matt-pocock set (ChatGPT: install all; skip deprecated/in-progress)
  local skill_md rel name
  while IFS= read -r skill_md; do
    rel="${skill_md#"${CACHE}"/mattpocock-skills/skills/}"
    rel="${rel%/SKILL.md}"
    [[ "$rel" == deprecated/* || "$rel" == in-progress/* ]] && continue
    name="matt-$(echo "$rel" | tr '/' '-')"
    copy_skill_dir "$(dirname "$skill_md")" "$name"
  done < <(find "${CACHE}/mattpocock-skills/skills" -name 'SKILL.md')
}

install_pstack() {
  local d
  for d in "${CACHE}/pstack/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    # Prefer official cursor/plugins copy when available (may be newer)
    local base name src
    base="$(basename "$d")"
    src="$d"
    if [[ -f "${CACHE}/cursor-plugins/pstack/skills/${base}/SKILL.md" ]]; then
      src="${CACHE}/cursor-plugins/pstack/skills/${base}"
    fi
    copy_skill_dir "$src" "pstack-${base}"
  done
  # Also copy playbooks directory referenced by poteto-mode if present
  if [[ -d "${CACHE}/pstack/skills/poteto-mode/playbooks" ]]; then
    for dest_root in "${REPO_TARGETS[@]}" "$HOME_CLAUDE" "$HOME_CURSOR" "$HOME_AGENTS"; do
      mkdir -p "${dest_root}/pstack-poteto-mode"
      rsync -a "${CACHE}/pstack/skills/poteto-mode/playbooks" "${dest_root}/pstack-poteto-mode/" 2>/dev/null || true
    done
  fi
}

install_shadcn_improve() {
  local src="${CACHE}/shadcn-improve/skills/improve"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "shadcn-improve"
}

install_coderabbit() {
  local d
  for d in "${CACHE}/coderabbit-skills/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "coderabbit-$(basename "$d")"
  done
}

install_vercel_agent_skills() {
  # Full vercel-labs/agent-skills pack (ChatGPT: essential for web)
  local d
  for d in "${CACHE}/vercel-agent-skills/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    case "$(basename "$d")" in
      react-native-skills) log "vercel skip: react-native-skills"; continue ;;
    esac
    copy_skill_dir "$d" "vercel-$(basename "$d")"
  done
}

install_vercel_find_skills() {
  local src="${CACHE}/vercel-skills/skills/find-skills"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "vercel-find-skills"
}

install_anthropic_dev() {
  local names=(mcp-builder webapp-testing skill-creator frontend-design claude-api)
  local name src
  for name in "${names[@]}"; do
    src="${CACHE}/anthropic-skills/skills/${name}"
    [[ -d "$src" && -f "${src}/SKILL.md" ]] || continue
    copy_skill_dir "$src" "anthropic-${name}"
  done
}

install_trailofbits_promoted() {
  # Full trailofbits repo vendored (ChatGPT: install complete repository)
  local skill_dir plugin skill
  for skill_dir in "${CACHE}/trailofbits/plugins"/*/skills/*; do
    [[ -d "$skill_dir" && -f "${skill_dir}/SKILL.md" ]] || continue
    plugin="$(basename "$(dirname "$(dirname "$skill_dir")")")"
    skill="$(basename "$skill_dir")"
    copy_skill_dir "$skill_dir" "tob-${plugin}-${skill}"
  done
}

install_agent_browser() {
  local names=(agent-browser core)
  local name src
  for name in "${names[@]}"; do
    for src in \
      "${CACHE}/agent-browser/skills/${name}" \
      "${CACHE}/agent-browser/skill-data/${name}"; do
      [[ -d "$src" && -f "${src}/SKILL.md" ]] || continue
      copy_skill_dir "$src" "browser-${name}"
    done
  done
}

install_compound_engineering() {
  # Core compound loop — brainstorm → plan → work → review → compound
  local names=(
    ce-brainstorm
    ce-plan
    ce-work
    ce-code-review
    ce-compound
    ce-handoff
    ce-setup
    ce-debug
    ce-proof
    ce-simplify-code
    ce-resolve-pr-feedback
  )
  local name src
  for name in "${names[@]}"; do
    src="${CACHE}/compound-engineering/skills/${name}"
    [[ -d "$src" && -f "${src}/SKILL.md" ]] || continue
    copy_skill_dir "$src" "${name}"
  done
}

install_awesome_copilot_promoted() {
  local names=(
    acquire-codebase-knowledge
    agent-governance
    agent-supply-chain
    ai-prompt-engineering-safety-review
    breakdown-feature-implementation
    breakdown-feature-prd
    codebase-memory-mcp
    create-readme
    create-github-issue-feature-from-specification
    generate-custom-instructions-from-codebase
    github-actions-efficiency
    create-agentsmd
  )
  local name src
  for name in "${names[@]}"; do
    src="${CACHE}/awesome-copilot/skills/${name}"
    [[ -d "$src" && -f "${src}/SKILL.md" ]] || continue
    copy_skill_dir "$src" "gh-${name}"
  done
}

install_supabase() {
  local d
  for d in "${CACHE}/supabase-skills/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "supabase-$(basename "$d")"
  done
}

install_cloudflare() {
  local d
  for d in "${CACHE}/cloudflare-skills/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "cloudflare-$(basename "$d")"
  done
}

install_microsoft_selective() {
  # General dev skills from .github/skills (not 175+ Azure SDK plugins)
  local d
  for d in "${CACHE}/microsoft-skills/.github/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "ms-$(basename "$d")"
  done
}

install_aws_core() {
  # AWS core-skills cartridge (not full 150+ specialized set)
  local d
  for d in "${CACHE}/aws-toolkit/skills/core-skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "aws-$(basename "$d")"
  done
}

install_last30days() {
  local src="${CACHE}/last30days/skills/last30days"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "last30days"
}

install_deep_research() {
  local src="${CACHE}/agent-deep-research"
  [[ -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "research-deep"
}

install_hallmark() {
  local src="${CACHE}/hallmark/skills/hallmark"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "hallmark"
}

install_remotion() {
  local d
  for d in "${CACHE}/remotion-skills/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "remotion-$(basename "$d")"
  done
}

install_nvidia_finder() {
  # Skill discovery for NVIDIA catalog; install domain NVIDIA skills on demand.
  local src="${CACHE}/nvidia-skills/plugins/nvidia-skills/skills/nvidia-skill-finder"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || return 0
  copy_skill_dir "$src" "nvidia-skill-finder"
}

install_project_extras() {
  # High-value for agent-org: gated loops, CLI control, PR/review workflows
  # cursor-team-kit
  for d in "${CACHE}/cursor-plugins/cursor-team-kit/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "ctk-$(basename "$d")"
  done
  # ralph-loop (self-referential iteration — adjacent to review-loop)
  for d in "${CACHE}/cursor-plugins/ralph-loop/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "$(basename "$d")"
  done
  # orchestrate
  for d in "${CACHE}/cursor-plugins/orchestrate/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "cursor-$(basename "$d")"
  done
  # continual-learning
  for d in "${CACHE}/cursor-plugins/continual-learning/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "cursor-$(basename "$d")"
  done
  # cli-for-agent
  for d in "${CACHE}/cursor-plugins/cli-for-agent/skills"/*; do
    [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
    copy_skill_dir "$d" "cursor-$(basename "$d")"
  done
  # teaching, create-plugin, agent-compatibility
  for plugin in teaching create-plugin agent-compatibility; do
    for d in "${CACHE}/cursor-plugins/${plugin}/skills"/*; do
      [[ -d "$d" && -f "${d}/SKILL.md" ]] || continue
      copy_skill_dir "$d" "cursor-$(basename "$d")"
    done
  done
}

prune_stale_skills() {
  local dest_root skill_dir skill_name
  local -A keep=()
  local name
  for name in "${INSTALLED_SKILLS[@]}"; do
    keep["$name"]=1
  done
  for dest_root in "${REPO_TARGETS[@]}"; do
    [[ -d "$dest_root" ]] || continue
    for skill_dir in "${dest_root}"/*; do
      [[ -d "$skill_dir" ]] || continue
      skill_name="$(basename "$skill_dir")"
      case "$skill_name" in
        INDEX.txt|SKILL-PACKS.md|SKILL-ARCHITECTURE.md) continue ;;
      esac
      if [[ -z "${keep[$skill_name]:-}" ]]; then
        log "prune stale skill: ${skill_name}"
        rm -rf "$skill_dir"
      fi
    done
  done
}

write_index() {
  local index="${ROOT}/.claude/skills/INDEX.txt"
  mkdir -p "$(dirname "$index")"
  printf '%s\n' "${INSTALLED_SKILLS[@]}" | sort -u > "$index"
  cp "$index" "${ROOT}/.agents/skills/INDEX.txt"
  cp "$index" "${ROOT}/.agnets/skills/INDEX.txt"
}

write_manifest() {
  local manifest="${ROOT}/.claude/skills/SKILL-PACKS.md"
  mkdir -p "$(dirname "$manifest")"
  cat > "$manifest" << 'MANIFEST'
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

- **gstack**: iOS, browse binary, gbrain, heavy design assets
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

Also syncs into `~/.claude/skills`, `~/.cursor/skills`, and `~/.agents/skills` for Cloud Agent / global discovery.
MANIFEST
  # Mirror manifest
  for dest_root in "${ROOT}/.agents/skills" "${ROOT}/.agnets/skills"; do
    mkdir -p "$dest_root"
    cp "$manifest" "${dest_root}/SKILL-PACKS.md"
    [[ -f "${ROOT}/.claude/skills/SKILL-ARCHITECTURE.md" ]] && \
      cp "${ROOT}/.claude/skills/SKILL-ARCHITECTURE.md" "${dest_root}/SKILL-ARCHITECTURE.md"
  done
}

require_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq "$cmd"
  fi
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: required command not found: $cmd"
    exit 1
  fi
}

main() {
  require_command rsync
  require_command git

  ensure_cache
  log "Installing gstack (slim)…"
  install_gstack_slim
  log "Installing superpowers…"
  install_superpowers
  log "Installing matt-pocock (full set)…"
  install_matt_pocock
  log "Installing pstack…"
  install_pstack
  log "Installing shadcn/improve…"
  install_shadcn_improve
  log "Installing CodeRabbit skills…"
  install_coderabbit
  log "Installing Vercel agent skills (full pack)…"
  install_vercel_agent_skills
  log "Installing Vercel find-skills…"
  install_vercel_find_skills
  log "Installing Anthropic dev skills (slim)…"
  install_anthropic_dev
  log "Installing Trail of Bits security skills (full repo)…"
  install_trailofbits_promoted
  log "Installing agent-browser skills…"
  install_agent_browser
  log "Installing Compound Engineering core loop…"
  install_compound_engineering
  log "Installing GitHub awesome-copilot (promoted)…"
  install_awesome_copilot_promoted
  log "Installing Supabase skills…"
  install_supabase
  log "Installing Cloudflare skills…"
  install_cloudflare
  log "Installing Microsoft dev skills (selective)…"
  install_microsoft_selective
  log "Installing AWS core skills…"
  install_aws_core
  log "Installing last30days…"
  install_last30days
  log "Installing deep research…"
  install_deep_research
  log "Installing Hallmark UI art direction…"
  install_hallmark
  log "Installing Remotion skills…"
  install_remotion
  log "Installing NVIDIA skill finder…"
  install_nvidia_finder
  log "Installing project extras…"
  install_project_extras
  write_manifest
  write_index
  prune_stale_skills

  local count
  count="$(find "${ROOT}/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  log "Done. ${count} skill dirs under .claude/skills/"
}

main "$@"
