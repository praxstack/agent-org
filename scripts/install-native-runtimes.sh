#!/usr/bin/env bash
# Native skill runtimes that need harness setup beyond vendored SKILL.md copies.
# Idempotent. Run after install-skill-packs.sh (or after sync_home_from_repo).
set -euo pipefail

CACHE="${SKILL_PACK_CACHE:-/tmp/skill-packs}"
GSTACK_REPO="${GSTACK_REPO:-${CACHE}/gstack}"

log() { printf '[native-runtimes] %s\n' "$*" >&2; }

ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    return 0
  fi
  log "Installing bun (required for gstack native setup)…"
  curl -fsSL https://bun.sh/install | bash
  export PATH="${HOME}/.bun/bin:${PATH}"
  if ! command -v bun >/dev/null 2>&1; then
    log "ERROR: bun install failed"
    exit 1
  fi
}

ensure_gstack_source() {
  mkdir -p "$(dirname "$GSTACK_REPO")"
  if [[ -d "${GSTACK_REPO}/.git" ]]; then
    log "Refreshing gstack cache at ${GSTACK_REPO}…"
    if ! git -C "$GSTACK_REPO" fetch --depth 1 origin HEAD; then
      log "WARN: fetch failed; re-cloning gstack"
      rm -rf "$GSTACK_REPO"
      git clone --depth 1 --single-branch https://github.com/garrytan/gstack.git "$GSTACK_REPO"
      return
    fi
    git -C "$GSTACK_REPO" reset --hard FETCH_HEAD
    return
  fi
  log "Cloning gstack into ${GSTACK_REPO}…"
  git clone --depth 1 --single-branch https://github.com/garrytan/gstack.git "$GSTACK_REPO"
}

clear_vendored_gstack_skills() {
  local d
  for d in "${HOME}/.cursor/skills"/gstack-*; do
    [[ -e "$d" ]] || continue
    if [[ -L "$d" ]]; then
      continue
    fi
    log "Removing vendored $(basename "$d") so native gstack can link generated skills"
    rm -rf "$d"
  done
}

install_gstack_cursor() {
  ensure_bun
  ensure_gstack_source
  clear_vendored_gstack_skills
  log "Running gstack ./setup --host cursor --no-prefix (native runtime + skills)…"
  (
    cd "$GSTACK_REPO"
    ./setup --host cursor --no-prefix -q
  )
  if [[ -d "${HOME}/.cursor/skills/gstack/bin" ]]; then
    log "gstack runtime OK: ${HOME}/.cursor/skills/gstack/bin"
  else
    log "WARN: gstack runtime root missing after setup"
    exit 1
  fi
}

main() {
  local target="${1:-cursor}"
  case "$target" in
    cursor|all|cursor+gstack)
      install_gstack_cursor
      ;;
    *)
      log "Unknown target: $target (use: cursor)"
      exit 1
      ;;
  esac
  log "Native runtime install complete."
}

main "$@"
