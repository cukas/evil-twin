#!/usr/bin/env bash
# Evil Twin — Doppelganger CLI adapter for AI Buddies integration
# Works as a standalone CLI binary that buddy-run.sh can invoke.
#
# Protocol (AI Buddies adapter):
#   - Reads task prompt from stdin
#   - Solves BLIND in the provided --cwd (typically a forge worktree)
#   - Outputs solution to stdout
#
# Standalone mode (no stdin):
#   doppelganger-cli.sh --prompt "..." --cwd /path/to/repo [--timeout 360]
#   Creates its own worktree, solves, outputs, cleans up.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PLUGIN_ROOT}/hooks/lib.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
PROMPT=""
CWD=""
TIMEOUT="360"
STANDALONE_WORKTREE=""
CLEANUP_WORKTREE=false

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)  PROMPT="$2";  shift 2 ;;
    --cwd)     CWD="$2";     shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ── Read prompt from stdin if not provided via --prompt ──────────────────────
# AI Buddies adapter protocol: buddy-run.sh pipes prompt via stdin
if [[ -z "$PROMPT" ]]; then
  if [[ ! -t 0 ]]; then
    PROMPT="$(cat)"
  fi
fi

if [[ -z "$PROMPT" ]]; then
  echo "ERROR: No prompt provided (via --prompt or stdin)" >&2
  exit 1
fi

# ── Find claude CLI ──────────────────────────────────────────────────────────
CLAUDE_BIN=""
# 1. Explicit config override
_configured="$(evil_twin_config "claude_path" "")"
if [[ -n "$_configured" && -x "$_configured" ]]; then
  CLAUDE_BIN="$_configured"
fi
# 2. Standard PATH lookup
if [[ -z "$CLAUDE_BIN" ]] && command -v claude &>/dev/null; then
  CLAUDE_BIN="$(command -v claude)"
fi
# 3. Common install locations
if [[ -z "$CLAUDE_BIN" ]]; then
  for candidate in \
    "${HOME}/.local/bin/claude" \
    "/usr/local/bin/claude" \
    "${HOME}/.nvm/versions/node/"*/bin/claude; do
    if [[ -x "$candidate" ]]; then
      CLAUDE_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$CLAUDE_BIN" ]]; then
  echo "ERROR: claude CLI not found. Install: npm install -g @anthropic-ai/claude-code" >&2
  exit 1
fi

evil_twin_debug "doppelganger-cli: claude=$CLAUDE_BIN, timeout=$TIMEOUT"

# ── Resolve working directory ────────────────────────────────────────────────
# If CWD is provided (forge mode), use it directly — forge already created a worktree.
# If no CWD, create a standalone worktree from the current repo.
if [[ -z "$CWD" ]]; then
  CWD="$(pwd)"
fi

# Check if CWD is inside a git repo
REPO_ROOT=""
REPO_ROOT=$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null) || true

if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: --cwd is not inside a git repository" >&2
  exit 1
fi

# Determine if we need to create our own worktree.
# If CWD is already a worktree (different from repo root), forge created it — use as-is.
# If CWD IS the repo root, we need our own worktree for isolation.
WT_ROOT=""
WT_ROOT=$(cd "$CWD" && git rev-parse --show-toplevel 2>/dev/null) || true
IS_WORKTREE=false
if [[ -n "$WT_ROOT" ]]; then
  COMMON_DIR=$(cd "$CWD" && git rev-parse --git-common-dir 2>/dev/null) || true
  GIT_DIR=$(cd "$CWD" && git rev-parse --git-dir 2>/dev/null) || true
  # If git-dir != git-common-dir, this is a worktree (not the main repo)
  if [[ -n "$COMMON_DIR" && -n "$GIT_DIR" ]]; then
    COMMON_RESOLVED=$(cd "$CWD" && cd "$COMMON_DIR" && pwd)
    GIT_RESOLVED=$(cd "$CWD" && cd "$GIT_DIR" && pwd)
    if [[ "$COMMON_RESOLVED" != "$GIT_RESOLVED" ]]; then
      IS_WORKTREE=true
    fi
  fi
fi

WORK_DIR="$CWD"

if [[ "$IS_WORKTREE" == "false" ]]; then
  # Create a standalone worktree for blind solving
  HEAD_SHA=$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null) || {
    echo "ERROR: Cannot determine HEAD commit" >&2
    exit 1
  }

  STANDALONE_WORKTREE="/tmp/doppelganger-wt-$(date '+%Y%m%d-%H%M%S')-$$"

  git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
  git -C "$REPO_ROOT" worktree add --detach "$STANDALONE_WORKTREE" "$HEAD_SHA" >/dev/null 2>&1 || {
    echo "ERROR: Failed to create worktree at $STANDALONE_WORKTREE" >&2
    exit 1
  }
  CLEANUP_WORKTREE=true
  WORK_DIR="$STANDALONE_WORKTREE"

  # Symlink node_modules if present (same pattern as forge-run.sh)
  if [[ -d "${REPO_ROOT}/node_modules" && ! -e "${WORK_DIR}/node_modules" ]]; then
    ln -s "${REPO_ROOT}/node_modules" "${WORK_DIR}/node_modules" 2>/dev/null || true
  fi
  # Per-package node_modules (pnpm workspaces)
  for pkg_nm in "${REPO_ROOT}"/packages/*/node_modules; do
    [[ -d "$pkg_nm" ]] || continue
    pkg_name="$(basename "$(dirname "$pkg_nm")")"
    target_dir="${WORK_DIR}/packages/${pkg_name}"
    if [[ -d "$target_dir" && ! -e "${target_dir}/node_modules" ]]; then
      ln -s "$pkg_nm" "${target_dir}/node_modules" 2>/dev/null || true
    fi
  done

  evil_twin_debug "doppelganger-cli: created standalone worktree at $STANDALONE_WORKTREE"
fi

# ── Cleanup trap ─────────────────────────────────────────────────────────────
_doppel_cleanup() {
  if [[ "$CLEANUP_WORKTREE" == "true" && -n "$STANDALONE_WORKTREE" && -d "$STANDALONE_WORKTREE" ]]; then
    git -C "$REPO_ROOT" worktree remove "$STANDALONE_WORKTREE" --force 2>/dev/null || true
    evil_twin_debug "doppelganger-cli: cleaned up worktree $STANDALONE_WORKTREE"
  fi
}
trap _doppel_cleanup EXIT INT TERM

# ── Auto-detect project context ──────────────────────────────────────────────
PROJECT_JSON=""
if [[ -x "${PLUGIN_ROOT}/scripts/detect-project.sh" ]]; then
  PROJECT_JSON=$(bash "${PLUGIN_ROOT}/scripts/detect-project.sh" "$WORK_DIR" 2>/dev/null) || PROJECT_JSON=""
fi

LANG_DETECTED="unknown"
BUILD_CMD="echo 'no build'"
TEST_CMD="echo 'no test'"
if [[ -n "$PROJECT_JSON" ]] && command -v jq &>/dev/null; then
  LANG_DETECTED=$(echo "$PROJECT_JSON" | jq -r '.language // "unknown"' 2>/dev/null || echo "unknown")
  BUILD_CMD=$(echo "$PROJECT_JSON" | jq -r '.build_cmd // "echo no build"' 2>/dev/null || echo "echo 'no build'")
  TEST_CMD=$(echo "$PROJECT_JSON" | jq -r '.test_cmd // "echo no test"' 2>/dev/null || echo "echo 'no test'")
fi

# ── Build the blind Doppelganger prompt ──────────────────────────────────────
# The key contract: the Doppelganger gets the TASK only — no prior solution,
# no discussion of approaches, no hints. Pure blind solve.
DOPPEL_PROMPT="You are the Doppelganger — an independent engineer solving a problem from scratch in a clean worktree. You have NOT seen any prior solution. Your job is to produce working code.

RULES:
1. Solve the problem independently. Do NOT look for or reference any prior solution attempts.
2. Read the codebase to understand the existing architecture, patterns, and conventions.
3. Write actual code that solves the problem. Follow existing patterns.
4. Run the build command to verify: ${BUILD_CMD}
5. Run the test suite to verify: ${TEST_CMD}
6. If ambiguous, make an assumption and DOCUMENT it.
7. Keep your solution focused. Do not refactor unrelated code.
8. After implementing, produce a brief summary of your approach, files changed, and build/test results.

PROJECT CONTEXT:
- Language: ${LANG_DETECTED}
- Build: ${BUILD_CMD}
- Test: ${TEST_CMD}

TASK:
${PROMPT}"

# ── Run claude in the worktree ───────────────────────────────────────────────
evil_twin_debug "doppelganger-cli: dispatching claude --print in $WORK_DIR"

CLAUDE_ARGS=(
  --print
  -p "$DOPPEL_PROMPT"
  --allowedTools "Edit,Write,Read,Bash,Glob,Grep"
  --max-turns 50
)

# Use configured model if set
MODEL="$(evil_twin_config "doppelganger_model" "")"
[[ -n "$MODEL" ]] && CLAUDE_ARGS+=(--model "$MODEL")

# ── Timeout wrapper (portable, same as AI Buddies) ───────────────────────────
_run_with_timeout() {
  local secs="$1"
  shift
  if command -v gtimeout &>/dev/null; then
    gtimeout "${secs}s" "$@"
  elif command -v timeout &>/dev/null; then
    timeout "${secs}s" "$@"
  else
    # Perl fallback for macOS
    perl -e '
      use POSIX qw(setpgid);
      alarm shift @ARGV;
      $pid = fork;
      if ($pid == 0) { setpgid(0,0); exec @ARGV; die "exec failed: $!" }
      $SIG{ALRM} = sub { kill -9, $pid; exit 124 };
      waitpid $pid, 0;
      exit ($? >> 8);
    ' "$secs" "$@"
  fi
}

EXIT_CODE=0
cd "$WORK_DIR"
# Unset CLAUDECODE so the subprocess doesn't think it's nested in a parent session
unset CLAUDECODE 2>/dev/null || true

_run_with_timeout "$TIMEOUT" "$CLAUDE_BIN" \
  "${CLAUDE_ARGS[@]}" \
  2>/dev/null || EXIT_CODE=$?

# ── Handle exit codes ────────────────────────────────────────────────────────
if [[ $EXIT_CODE -eq 124 ]]; then
  echo "TIMEOUT: Doppelganger did not complete within ${TIMEOUT}s" >&2
  evil_twin_debug "doppelganger-cli: timed out after ${TIMEOUT}s"
  exit 124
elif [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Doppelganger claude exited with code ${EXIT_CODE}" >&2
  evil_twin_debug "doppelganger-cli: claude exited with code ${EXIT_CODE}"
  exit "$EXIT_CODE"
fi

evil_twin_debug "doppelganger-cli: complete, exit=0"
