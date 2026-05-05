#!/usr/bin/env bash
# _shared.sh — Git pull function used by build.sh and deploy.sh
# Source this file: source "$(dirname "$0")/_shared.sh"

sync_project() {
  local proj=$1
  local proj_dir="$DEPLOY_DIR/$proj"

  if [[ ! -d "$proj_dir/.git" ]]; then
    echo "  --- $proj: not a git repo, skipping ---"
    return
  fi

  echo "  Pulling $proj from origin/main"
  git -C "$proj_dir" fetch origin
  git -C "$proj_dir" reset --hard origin/main
}
