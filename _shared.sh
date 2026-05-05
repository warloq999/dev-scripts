#!/usr/bin/env bash
# _shared.sh — Git sync functions used by build.sh and deploy.sh
# Source this file: source "$(dirname "$0")/_shared.sh"

set -euo pipefail

WORKSPACES=(hermes antigravity kiro cursor)
PROJECTS=(ai_email_workflow dragonAgent obsidian-task-service portfolioDash)

# ── Step 1: Sync all workspaces with each other and push to GitHub ──────────────
sync_workspaces() {
  echo ""
  echo "  [workspace sync] Syncing all workspaces to GitHub..."

  for ws in "${WORKSPACES[@]}"; do
    for proj in "${PROJECTS[@]}"; do
      local proj_dir="/home/dragonagent/vibecoders/$ws/$proj"
      if [[ ! -d "$proj_dir/.git" ]]; then
        continue
      fi

      if ! git -C "$proj_dir" rev-parse '@{upstream}' &>/dev/null; then
        continue
      fi

      echo "    $ws/$proj"

      # Stash any unstaged changes before touching the repo
      if ! git -C "$proj_dir" diff-index --quiet HEAD -- 2>/dev/null; then
        echo "    $ws/$proj — stashing unstaged changes..."
        git -C "$proj_dir" stash --include-untracked -q
      fi

      # Fetch latest from origin
      git -C "$proj_dir" fetch origin --quiet

      # Pull if origin is ahead (converge — no force push)
      if git -C "$proj_dir" log HEAD..origin/main --oneline | grep -q .; then
        remote_ahead=$(git -C "$proj_dir" log HEAD..origin/main --oneline | wc -l)
        echo "    $ws/$proj — origin is $remote_ahead commit(s) ahead, pulling..."
        git -C "$proj_dir" pull origin main --rebase -q
      fi

      # Push if local has commits not on origin/main
      if git -C "$proj_dir" log origin/main..HEAD --oneline | grep -q .; then
        local_ahead=$(git -C "$proj_dir" log origin/main..HEAD --oneline | wc -l)
        echo "    $ws/$proj — $local_ahead commit(s) ahead of origin, pushing..."
        if ! git -C "$proj_dir" push origin main 2>&1; then
          echo "    $ws/$proj — remote moved, rebasing on top of origin/main..."
          if git -C "$proj_dir" fetch origin main --quiet && \
             git -C "$proj_dir" rebase origin/main 2>&1; then
            echo "    $ws/$proj — rebase successful, pushing..."
            git -C "$proj_dir" push origin main
          else
            echo "    $ws/$proj — rebase conflict, aborting and skipping"
            git -C "$proj_dir" rebase --abort &>/dev/null || true
          fi
        fi
      fi

      # Restore stashed changes if any
      if git -C "$proj_dir" stash list | grep -q .; then
        echo "    $ws/$proj — restoring stashed changes..."
        git -C "$proj_dir" stash pop -q 2>/dev/null || true
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
