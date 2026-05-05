#!/usr/bin/env bash
# sync-to-deploy.sh — Rsync all dockerized projects from ~/vibecoders/<agent>/ to ~/vibecoders/deploy/
# Only copies projects that have a docker-compose.yml (the 4 dockerized ones).
# Running this on ANY agent's copy works since all agents are in sync via the repo sync cron.

set -euo pipefail

VIBECODERS_DIR="/home/dragonagent/vibecoders"
DEPLOY_DIR="$VIBECODERS_DIR/deploy"
PROJECTS=(ai_email_workflow dragonAgent obsidian-task-service portfolioDash)

echo "========================================"
echo "  Syncing to $DEPLOY_DIR"
echo "========================================"

mkdir -p "$DEPLOY_DIR"

for proj in "${PROJECTS[@]}"; do
  src="$VIBECODERS_DIR/hermes/$proj"   # hermes is the source of truth
  dst="$DEPLOY_DIR/$proj"

  if [[ ! -d "$src" ]]; then
    echo "  --- $proj: source not found in hermes/, skipping ---"
    continue
  fi

  if [[ ! -f "$src/docker-compose.yml" ]]; then
    echo "  --- $proj: no docker-compose.yml, skipping ---"
    continue
  fi

  echo "  --- $proj ---"
  rsync -av --exclude '.git' \
        --exclude '__pycache__' \
        --exclude '.pytest_cache' \
        --exclude 'scratch' \
        --exclude '.claude' \
        --exclude 'node_modules' \
        --exclude '.env' \
        --exclude 'data' \
        --exclude 'logs' \
        --exclude 'backups' \
        --exclude 'imports' \
        --exclude 'docker-compose.yml' \
        --exclude 'docker-compose.*.yml' \
        --exclude 'docker-compose*.yml' \
        --exclude 'nginx.conf' \
        --exclude 'Dockerfile' \
        --exclude '.dockerignore' \
        --exclude 'docker-*.sh' \
        --exclude 'docker-*.ps1' \
        --exclude 'startup-entrypoint.sh' \
        "$src/" "$dst/"

  echo "  ✓ $proj synced"
done

echo ""
echo "✓ Sync complete"
