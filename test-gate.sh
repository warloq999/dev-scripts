#!/usr/bin/env bash
# =============================================================================
# test-gate.sh — Run tests before build/deploy
# Fails the pipeline if any project has failing tests.
# Auto-creates kanban task for vibecoder if tests fail.
# Usage: ./test-gate.sh [project|all]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

PROJECTS_ALL=(
  "ai_email_workflow"
  "squaddy"
  "obsidian-task-service"
  "portfolioDash2.0"
  "giveMeSlide"
  # foldsortr-ai has no test suite yet
)

declare -a PASSED=()
declare -a FAILED=()

log_section "Test Gate"

run_test() {
  local proj="$1"
  local ws_root="${HOME}/vibecoders"
  local src_dir=""
  local test_cmd=""
  local description=""

  case "$proj" in
    ai_email_workflow)
      src_dir="${ws_root}/apps/ai_email_workflow"
      test_cmd=".venv/bin/python -m pytest -q"
      description="pytest"
      ;;
    squaddy)
      src_dir="${ws_root}/apps/squaddy"
      test_cmd="npm test"
      description="vitest"
      ;;
    obsidian-task-service)
      src_dir="${ws_root}/apps/obsidian-task-service"
      test_cmd=".venv/bin/python -m pytest -q"
      description="pytest"
      ;;
    portfolioDash2.0)
      src_dir="${ws_root}/apps/portfolioDash2.0"
      test_cmd="npm test"
      description="vitest"
      ;;
    giveMeSlide)
      src_dir="${ws_root}/apps/giveMeSlide"
      test_cmd="npm test"
      description="vitest"
      ;;
    *)
      echo "  [SKIP] $proj — no test suite configured"
      return 0
      ;;
  esac

  if [[ ! -d "$src_dir" ]]; then
    echo "  [SKIP] $proj — source not found at $src_dir"
    return 0
  fi

  echo ""
  echo "  ▶ $proj ($description)"
  echo "    $test_cmd"

  # Detect project type and run
  if [[ "$proj" == "ai_email_workflow" || "$proj" == "obsidian-task-service" ]]; then
    # Python project — ensure .venv exists
    if [[ ! -f "${src_dir}/.venv/bin/python" ]]; then
      echo "    [WARN] .venv not found — skipping (run 'python -m venv .venv' first)"
      return 0
    fi
    if (cd "$src_dir" && .venv/bin/python -m pytest -q); then
      echo "    [PASS] $proj"
      PASSED+=("$proj")
    else
      echo "    [FAIL] $proj"
      FAILED+=("$proj")
      return 1
    fi

  elif [[ "$proj" == "squaddy" || "$proj" == "portfolioDash2.0" || "$proj" == "giveMeSlide" ]]; then
    # Node.js project — ensure node_modules exists
    if [[ ! -d "${src_dir}/node_modules" ]]; then
      echo "    [WARN] node_modules not found — skipping (run 'npm install' first)"
      return 0
    fi
    if (cd "$src_dir" && npm test); then
      echo "    [PASS] $proj"
      PASSED+=("$proj")
    else
      echo "    [FAIL] $proj"
      FAILED+=("$proj")
      return 1
    fi
  fi
}

if [[ "${1:-all}" == "all" ]]; then
  for proj in "${PROJECTS_ALL[@]}"; do
    run_test "$proj" || true
  done
else
  run_test "$1"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log_section "Test Gate — Summary"
echo -e "  ${C_GREEN}Passed${C_RESET}:  ${#PASSED[@]}  — ${PASSED[*]:-none}"
echo -e "  ${C_RED}Failed${C_RESET}:    ${#FAILED[@]}  — ${FAILED[*]:-none}"
echo ""

if [[ "${#FAILED[@]}" -gt 0 ]]; then
  echo -e "${C_RED}TEST GATE FAILED${C_RESET} — fix failing projects before deploying:"
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done

  # ── Auto-create kanban task for vibecoder ───────────────────────────────────
  FAILED_LIST=$(IFS=,; echo "${FAILED[*]}")
  TASK_TITLE="Fix failing tests: ${FAILED_LIST}"

  # Get detailed failure output for the task body
  FAILURE_DETAILS=""
  for proj in "${FAILED[@]}"; do
    ws_root="${HOME}/vibecoders"
    case "$proj" in
      ai_email_workflow|obsidian-task-service)
        fail_output=$("$ws_root/apps/$proj/.venv/bin/python" -m pytest -q 2>&1 | tail -30)
        ;;
      squaddy|portfolioDash2.0|giveMeSlide)
        fail_output=$(cd "$ws_root/apps/$proj" && npm test -- --run --reporter=basic 2>&1 | tail -30)
        ;;
    esac
    FAILURE_DETAILS="${FAILURE_DETAILS}\n\n### ${proj}:\n\`\`\`\n${fail_output}\n\`\`\`"
  done

  TASK_BODY="## Context
Tests failed in test-gate during nightly pipeline. Fix the failing tests so the deploy pipeline can proceed.

## Steps
1. Read the failure details below for ${FAILED_LIST}
2. Fix the failing tests in the source code at ~/vibecoders/apps/<project>/
3. Ensure tests pass: cd ~/vibecoders/apps/<project> && [test command]
4. Commit and push to origin/main
5. Verify the deploy pipeline picks up the fix

## Failure Details
${FAILURE_DETAILS}

## Important
- Fix MUST be committed and pushed from ~/vibecoders/apps/<project>/ (source), NOT deploy/
- Deploy dir pulls from GitHub on next run
- After fix, confirm tests pass locally before marking done"

  # Create kanban task
  echo ""
  echo "[INFO] Creating kanban task for failing tests..."
  task_id=$(hermes kanban create "${TASK_TITLE}" \
    --assignee worker \
    --profile worker \
    --tags test-fix \
    --body "${TASK_BODY}" 2>/dev/null | grep -oP 't_[a-f0-9]+' | tail -1 || echo "")

  if [[ -n "$task_id" ]]; then
    echo "[INFO] Kanban task created: ${task_id}"
  else
    echo "[WARN] Could not create kanban task — create manually for: ${FAILED_LIST}"
  fi

  exit 1
else
  echo -e "${C_GREEN}All tests passed ✓${C_RESET}"
  exit 0
fi