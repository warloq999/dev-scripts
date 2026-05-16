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

      # Always work on the main branch — save current branch first
      local original_branch
      original_branch=$(git -C "$proj_dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$proj_dir" rev-parse HEAD)
      local saved=0

      # Stash unstaged changes before touching anything
      if ! git -C "$proj_dir" diff-index --quiet HEAD -- 2>/dev/null; then
        echo "    $ws/$proj — stashing unstaged changes..."
        git -C "$proj_dir" stash --include-untracked -q
        saved=1
      fi

      # Fetch latest origin state
      git -C "$proj_dir" fetch origin --quiet

      # Pull origin/main into local main if origin is ahead
      if git -C "$proj_dir" log HEAD..origin/main --oneline | grep -q .; then
        local ahead=$(git -C "$proj_dir" log HEAD..origin/main --oneline | wc -l)
        echo "    $ws/$proj — origin/main is $ahead commit(s) ahead, pulling..."
        git -C "$proj_dir" checkout main -q 2>/dev/null || true
        git -C "$proj_dir" pull origin main --rebase -q
      fi

      # Push local main to origin/main if ahead
      if git -C "$proj_dir" log origin/main..main --oneline | grep -q .; then
        local_ahead=$(git -C "$proj_dir" log origin/main..main --oneline | wc -l)
        echo "    $ws/$proj — local main is $local_ahead commit(s) ahead of origin, pushing..."
        if ! git -C "$proj_dir" push origin main 2>&1; then
          echo "    $ws/$proj — rejected, rebasing local main on origin/main..."
          if git -C "$proj_dir" fetch origin main --quiet && \
             git -C "$proj_dir" rebase origin/main 2>&1; then
            git -C "$proj_dir" push origin main
          else
            echo "    $ws/$proj — rebase conflict, skipping push"
            git -C "$proj_dir" rebase --abort &>/dev/null || true
          fi
        fi
      fi

      # Return to original branch
      if [[ "$original_branch" != "main" ]]; then
        git -C "$proj_dir" checkout "$original_branch" -q 2>/dev/null || true
      fi

      # Restore stashed changes
      if [[ "$saved" == "1" ]]; then
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
