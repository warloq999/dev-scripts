#!/usr/bin/env bash
# enforce-deploy-readonly.sh — Pre-commit hook for deploy repos
# Blocks commits that modify source files (src/, *.tsx, *.ts)
# Install: ln -sf "$(dirname "$0")/enforce-deploy-readonly.sh" /path/to/deploy/repo/.git/hooks/pre-commit

set -euo pipefail

DEPLOY_DIR="/home/dragonagent/vibecoders/deploy"

# Get the repo root (handles being called from symlinked hooks)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  echo "enforce-deploy-readonly: not in a git repo, skipping"
  exit 0
fi

# Check if we're in a deploy repo (repo root is under DEPLOY_DIR)
case "$REPO_ROOT" in
  "$DEPLOY_DIR"/*) ;;   # allowed — inside deploy dir
  *) exit 0 ;;          # not a deploy repo — allow
esac

# Source files to block: src/ directory OR source file extensions
BLOCKED_PATTERNS="^src/|\.(tsx|ts|jsx|js|css|scss)$"

# Check staged files
if git diff --cached --name-only | grep -qE "$BLOCKED_PATTERNS"; then
  echo ""
  echo "=============================================="
  echo "  PRE-COMMIT BLOCKED"
  echo "=============================================="
  echo ""
  echo "  Source file changes are not allowed in deploy repos."
  echo "  Deploy repos are READ-ONLY mirrors — sync from GitHub."
  echo ""
  echo "  To deploy changes:"
  echo "    1. Make changes in: ~/vibecoders/apps/<project>/"
  echo "    2. Commit and push: cd ~/vibecoders/apps/<project> && git push"
  echo "    3. Deploy: cd ~/vibecoders/scripts && ./deploy.sh <project>"
  echo ""
  echo "  Blocked files:"
  git diff --cached --name-only | grep -E "$BLOCKED_PATTERNS" | while read -r f; do
    echo "    - $f"
  done
  echo ""
  exit 1
fi

# Also check working tree (unstaged) for accidental edits
if git ls-files --others --exclude-standard | grep -qE "$BLOCKED_PATTERNS"; then
  echo ""
  echo "  WARNING: Untracked source files found in deploy repo."
  echo "  These will be wiped on the next deploy."
  echo "  Move them to ~/vibecoders/apps/<project>/ instead."
  echo ""
fi

exit 0