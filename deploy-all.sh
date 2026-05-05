#!/usr/bin/env bash
# deploy-all.sh — Sync to deploy dir, build all, then deploy all
# Usage: ./deploy-all.sh [project|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="/home/dragonagent/vibecoders/scripts/sync-to-deploy.sh"

"$SYNC_SCRIPT"
"$SCRIPT_DIR/build.sh" "${1:-all}"
"$SCRIPT_DIR/deploy.sh" "${1:-all}"
