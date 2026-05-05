#!/usr/bin/env bash
# _shared.sh — Git sync functions used by build.sh and deploy.sh
# Source this file: source "$(dirname "$0")/_shared.sh"

set -euo pipefail

WORKSPACES=(hermes antigravity kiro cursor)
PROJECTS=(ai_email_workflow dragonAgent obsidian-task-service portfolioDash)

# ── Step 1: Sync all workspaces with each other and push to GitHub ──────────────
sync_workspaces() {
  echo ""
  echo "  [workspace sync] Pulling all workspaces from GitHub..."

  for ws in "${WORKSPACES[@]}"; do
    for proj in "${PROJECTS[@]}"; do
      local proj_dir="/home/dragonagent/vibecoders/$ws/$proj"
      if [[ ! -d "$proj_dir/.git" ]]; then
        continue
      fi

      # Pull from GitHub (origin) — handles any commits made directly in this workspace
      if git -C "$proj_dir" rev-parse '@{upstream}' &>/dev/null; then
        echo "    $ws/$proj — pulling from origin"
        git -C "$proj_dir" fetch origin --quiet
        if git -C "$proj_dir" log origin/main..HEAD --oneline | grep -q .; then
          echo "    $ws/$proj — pushing $(git -C "$proj_dir" log origin/main..HEAD --oneline | wc -l) commit(s) to origin"
          git -C "$proj_dir" push origin main
        fi
      fi
    done
  done

  echo "  [workspace sync] Done"
}

# ── Step 2: Pull latest into deploy dir from GitHub ─────────────────────────────
sync_project() {
  local proj=$1
  local proj_dir="$DEPLOY_DIR/$proj"

  if [[ ! -d "$proj_dir/.git" ]]; then
    echo "  --- $proj: not a git repo, skipping ---"
    return
  fi

  echo "  Pulling $proj from origin/main into deploy"
  git -C "$proj_dir" fetch origin
  git -C "$proj_dir" reset --hard origin/main
}
