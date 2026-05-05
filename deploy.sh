#!/usr/bin/env bash
# deploy.sh — Pull latest from origin/main + Deploy Docker services from ~/vibecoders/deploy/
# Usage: ./deploy.sh [project|all]
# Examples:
#   ./deploy.sh ai_email_workflow  # deploy single project
#   ./deploy.sh all                # deploy all 4 projects

set -euo pipefail

DEPLOY_DIR="/home/dragonagent/vibecoders/deploy"
source "$(dirname "$0")/_shared.sh"

PROJECTS=(ai_email_workflow dragonAgent obsidian-task-service portfolioDash)

echo "========================================"
echo "  Deploying from $DEPLOY_DIR"
echo "========================================"

deploy_project() {
  local proj=$1
  local proj_dir="$DEPLOY_DIR/$proj"
  local compose_file="$proj_dir/docker-compose.yml"
  local env_file="$proj_dir/.env"

  if [[ ! -f "$compose_file" ]]; then
    echo "  --- $proj: no docker-compose.yml, skipping ---"
    return
  fi

  echo ""
  echo "  --- $proj ---"

  # Backup prod .env before git reset wipes it
  local env_backup=""
  if [[ -f "$env_file" ]]; then
    env_backup=$(mktemp)
    cp "$env_file" "$env_backup"
    echo "  .env backed up"
  fi

  sync_project "$proj"

  # Restore .env after reset (git reset restores committed version, not ignored)
  if [[ -n "$env_backup" && -f "$env_backup" ]]; then
    cp "$env_backup" "$env_file"
    rm -f "$env_backup"
    echo "  .env restored"
  fi

  # Pull new images + recreate containers (always re-reads .env)
  docker compose -f "$compose_file" pull
  docker compose -f "$compose_file" up -d --force-recreate
}

if [[ "${1:-all}" == "all" ]]; then
  for proj in "${PROJECTS[@]}"; do
    deploy_project "$proj"
  done
else
  if [[ " ${PROJECTS[*]} " == *"$1 "* ]]; then
    deploy_project "$1"
  else
    echo "Unknown project: $1"
    echo "Available: all ${PROJECTS[*]}"
    exit 1
  fi
fi

echo ""
echo "✓ All services deployed"
