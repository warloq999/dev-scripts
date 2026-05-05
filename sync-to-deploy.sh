#!/usr/bin/env bash
# DEPRECATED — This script is no longer used.
# Sync chain is now: hermes → GitHub → deploy
# hermes/antigravity/kiro/cursor push to GitHub
# deploy pulls from GitHub via: git fetch origin && git reset --hard origin/main
# Run build.sh / deploy.sh directly instead.
echo "This script is deprecated. Use build.sh and deploy.sh instead."
exit 1
