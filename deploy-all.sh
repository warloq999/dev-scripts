#!/usr/bin/env bash
# deploy-all.sh — Build all + Deploy all from ~/vibecoders/deploy/
# Usage: ./deploy-all.sh [project|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/build.sh" "${1:-all}"
"$SCRIPT_DIR/deploy.sh" "${1:-all}"
