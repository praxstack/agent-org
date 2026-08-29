#!/usr/bin/env bash
# Cloud Agent install — idempotent bootstrap for praxstack/agent-org (+ sibling workspace)
set -euo pipefail

# Resolve repo root even when invoked via absolute path from multi-root env install.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

require_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq "$cmd"
  fi
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[cloud-agent-install] ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

require_command rsync
require_command git

sync_home_from_repo() {
  local repo_root="$1"
  local src="${repo_root}/.claude/skills"
  [[ -d "$src" ]] || return 0
  for dest in "${HOME}/.claude/skills" "${HOME}/.agents/skills"; do
    mkdir -p "$dest"
    rsync -a --delete \
      --exclude 'INDEX.txt' \
      --exclude 'SKILL-PACKS.md' \
      --exclude 'SKILL-ARCHITECTURE.md' \
      "${src}/" "${dest}/"
  done
  # Cursor: preserve gstack native runtime root (not vendored into repo).
  mkdir -p "${HOME}/.cursor/skills"
  rsync -a --delete \
    --exclude 'INDEX.txt' \
    --exclude 'SKILL-PACKS.md' \
    --exclude 'SKILL-ARCHITECTURE.md' \
    --exclude 'gstack/' \
    --exclude 'gstack-*/' \
    "${src}/" "${HOME}/.cursor/skills/"
  for dest in "${repo_root}/.agents/skills" "${repo_root}/.agnets/skills"; do
    mkdir -p "$dest"
    rsync -a --delete "${src}/" "$dest/"
  done
}

needs_skill_install() {
  local repo_root="$1"
  [[ ! -f "${repo_root}/.claude/skills/INDEX.txt" ]] || [[ ! -s "${repo_root}/.claude/skills/INDEX.txt" ]]
}

bootstrap_repo() {
  local repo_root="$1"
  if needs_skill_install "$repo_root"; then
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
  # Always mirror primary repo skills into sibling (keeps workspace in sync after updates)
  if [[ -d "${ROOT}/.claude/skills" ]]; then
    mkdir -p "${SIBLING}/.claude/skills" "${SIBLING}/.agents/skills" "${SIBLING}/.agnets/skills"
    rsync -a --delete "${ROOT}/.claude/skills/" "${SIBLING}/.claude/skills/"
    rsync -a --delete "${SIBLING}/.claude/skills/" "${SIBLING}/.agents/skills/"
    rsync -a --delete "${SIBLING}/.claude/skills/" "${SIBLING}/.agnets/skills/"
    if [[ -f "${ROOT}/.claude/skills/INDEX.txt" ]]; then
      cp "${ROOT}/.claude/skills/INDEX.txt" "${SIBLING}/.claude/skills/INDEX.txt"
      cp "${ROOT}/.claude/skills/INDEX.txt" "${SIBLING}/.agents/skills/INDEX.txt"
      cp "${ROOT}/.claude/skills/INDEX.txt" "${SIBLING}/.agnets/skills/INDEX.txt"
    fi
  fi
  sync_home_from_repo "$SIBLING"
fi

if [[ -x "${ROOT}/scripts/install-native-runtimes.sh" ]]; then
  echo "[cloud-agent-install] Installing native skill runtimes (gstack for Cursor)…"
  "${ROOT}/scripts/install-native-runtimes.sh" cursor || {
    echo "[cloud-agent-install] WARN: native runtime install failed; vendored gstack-* skills still available" >&2
  }
fi

echo "[cloud-agent-install] home mirrors: claude=$(find "${HOME}/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') cursor=$(find "${HOME}/.cursor/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
