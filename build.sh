#!/usr/bin/env bash
# build.sh — Pull latest from origin/main + Build all Docker images from ~/vibecoders/deploy/
# Usage: ./build.sh [project|all]
# Examples:
#   ./build.sh ai_email_workflow  # build single project
#   ./build.sh all                # build all 4 projects

set -euo pipefail

DEPLOY_DIR="$HOME/vibecoders/deploy"
source "$(dirname "$0")/_shared.sh"

PROJECTS=(ai_email_workflow dragonAgent obsidian-task-service portfolioDash)

echo "========================================"
echo "  Building from $DEPLOY_DIR"
echo "========================================"

build_project() {
  local proj=$1
  local proj_dir="$DEPLOY_DIR/$proj"
  local compose_file="$proj_dir/docker-compose.yml"

  if [[ ! -f "$compose_file" ]]; then
    echo "  --- $proj: no docker-compose.yml, skipping ---"
    return
  fi

  echo ""
  echo "  --- $proj ---"
  sync_project "$proj"
  docker compose -f "$compose_file" build
}

if [[ "${1:-all}" == "all" ]]; then
  for proj in "${PROJECTS[@]}"; do
    build_project "$proj"
  done
else
  if [[ " ${PROJECTS[*]} " == *" $1 "* ]]; then
    build_project "$1"
  else
    echo "Unknown project: $1"
    echo "Available: all ${PROJECTS[*]}"
    exit 1
  fi
fi

echo ""
echo "✓ All builds complete"
