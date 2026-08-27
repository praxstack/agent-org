#!/usr/bin/env bash
# install-skill-packs.sh — vendor agent skill packs into this repo + home dirs.
# Idempotent. Safe for Cloud Agent install scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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
}

ensure_cache() {
  mkdir -p "$CACHE"
  log "Refreshing skill pack sources in ${CACHE}"
  need_git_clone https://github.com/garrytan/gstack.git "${CACHE}/gstack"
  need_git_clone https://github.com/obra/superpowers.git "${CACHE}/superpowers"
  need_git_clone https://github.com/mattpocock/skills.git "${CACHE}/mattpocock-skills"
  need_git_clone https://github.com/backnotprop/pstack.git "${CACHE}/pstack"
  need_git_clone https://github.com/cursor/plugins.git "${CACHE}/cursor-plugins"
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
  # Promoted set from .claude-plugin/plugin.json (engineering + productivity)
  local paths=(
    engineering/ask-matt
    engineering/diagnosing-bugs
    engineering/grill-with-docs
    engineering/triage
    engineering/improve-codebase-architecture
    engineering/setup-matt-pocock-skills
    engineering/tdd
    engineering/to-spec
    engineering/to-tickets
    engineering/wayfinder
    engineering/implement
    engineering/prototype
    engineering/research
    engineering/domain-modeling
    engineering/codebase-design
    engineering/code-review
    engineering/resolving-merge-conflicts
    engineering/wizard
    productivity/grill-me
    productivity/grilling
    productivity/handoff
    productivity/teach
    productivity/to-questionnaire
    productivity/wait-what
    productivity/writing-for-agents
  )
  local p
  for p in "${paths[@]}"; do
    local src="${CACHE}/mattpocock-skills/skills/${p}"
    [[ -d "$src" ]] || continue
    local name
    name="$(basename "$p")"
    copy_skill_dir "$src" "matt-${name}"
  done
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
MANIFEST
  # Mirror manifest
  for dest_root in "${ROOT}/.agents/skills" "${ROOT}/.agnets/skills"; do
    mkdir -p "$dest_root"
    cp "$manifest" "${dest_root}/SKILL-PACKS.md"
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
  log "Installing matt-pocock promoted set…"
  install_matt_pocock
  log "Installing pstack…"
  install_pstack
  log "Installing project extras…"
  install_project_extras
  write_manifest

  local count
  count="$(find "${ROOT}/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  log "Done. ${count} skill dirs under .claude/skills/"
  find "${ROOT}/.claude/skills" -mindepth 1 -maxdepth 1 -type d | sed 's|.*/||' | sort > "${ROOT}/.claude/skills/INDEX.txt"
  cp "${ROOT}/.claude/skills/INDEX.txt" "${ROOT}/.agents/skills/INDEX.txt"
  cp "${ROOT}/.claude/skills/INDEX.txt" "${ROOT}/.agnets/skills/INDEX.txt"
}

main "$@"
