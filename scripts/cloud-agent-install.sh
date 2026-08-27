#!/usr/bin/env bash
# Cloud Agent install — idempotent bootstrap for praxstack/agent-org (+ sibling workspace)
set -euo pipefail

# Resolve repo root even when invoked via absolute path from multi-root env install.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PATH="${HOME}/.bun/bin:${PATH}"

if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.sh/install | bash || true
  export PATH="${HOME}/.bun/bin:${PATH}"
fi

if ! command -v rsync >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq rsync
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq jq
  fi
fi

sync_home_from_repo() {
  local repo_root="$1"
  local src="${repo_root}/.claude/skills"
  [[ -d "$src" ]] || return 0
  for dest in "${HOME}/.claude/skills" "${HOME}/.cursor/skills" "${HOME}/.agents/skills"; do
    mkdir -p "$dest"
    rsync -a \
      --exclude 'INDEX.txt' \
      --exclude 'SKILL-PACKS.md' \
      "${src}/" "${dest}/"
  done
  for dest in "${repo_root}/.agents/skills" "${repo_root}/.agnets/skills"; do
    mkdir -p "$dest"
    rsync -a --delete "${src}/" "$dest/"
  done
}

bootstrap_repo() {
  local repo_root="$1"
  if [[ ! -f "${repo_root}/.claude/skills/INDEX.txt" ]] || [[ ! -s "${repo_root}/.claude/skills/INDEX.txt" ]]; then
    if [[ -x "${repo_root}/scripts/install-skill-packs.sh" ]]; then
      "${repo_root}/scripts/install-skill-packs.sh"
    fi
  else
    sync_home_from_repo "$repo_root"
  fi
  echo "[cloud-agent-install] $(basename "$repo_root"): $(find "${repo_root}/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') skill dirs"
}

bootstrap_repo "$ROOT"

SIBLING="$(cd "${ROOT}/.." && pwd)/agent-org-workspace"
if [[ -d "$SIBLING" && "$SIBLING" != "$ROOT" ]]; then
  if [[ ! -f "${SIBLING}/.claude/skills/INDEX.txt" ]]; then
    mkdir -p "${SIBLING}/.claude/skills" "${SIBLING}/.agents/skills" "${SIBLING}/.agnets/skills"
    rsync -a "${ROOT}/.claude/skills/" "${SIBLING}/.claude/skills/"
    rsync -a --delete "${SIBLING}/.claude/skills/" "${SIBLING}/.agents/skills/"
    rsync -a --delete "${SIBLING}/.claude/skills/" "${SIBLING}/.agnets/skills/"
  fi
  sync_home_from_repo "$SIBLING"
fi

echo "[cloud-agent-install] home mirrors: claude=$(find "${HOME}/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') cursor=$(find "${HOME}/.cursor/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
