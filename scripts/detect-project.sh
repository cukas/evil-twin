#!/usr/bin/env bash
# Evil Twin — project auto-detection
# Outputs JSON: language, build_cmd, test_cmd, file_tree, entry_points
set -euo pipefail

CWD="${1:-.}"
cd "$CWD"

# Detect language and tooling
LANG="unknown"
BUILD_CMD="echo 'no build command detected'"
TEST_CMD="echo 'no test command detected'"

if [ -f "package.json" ]; then
  LANG="typescript/javascript"
  if grep -q '"build"' package.json 2>/dev/null; then
    BUILD_CMD="npm run build"
  fi
  if grep -q '"test"' package.json 2>/dev/null; then
    TEST_CMD="npm test"
  fi
  # Check for specific runners
  if [ -f "tsconfig.json" ]; then
    LANG="typescript"
    BUILD_CMD="npx tsc --noEmit"
  fi
elif [ -f "Cargo.toml" ]; then
  LANG="rust"
  BUILD_CMD="cargo build"
  TEST_CMD="cargo test"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
  LANG="python"
  BUILD_CMD="python -m py_compile"
  if [ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml 2>/dev/null; then
    TEST_CMD="pytest"
  elif [ -d "tests" ]; then
    TEST_CMD="pytest"
  else
    TEST_CMD="python -m unittest discover"
  fi
elif [ -f "go.mod" ]; then
  LANG="go"
  BUILD_CMD="go build ./..."
  TEST_CMD="go test ./..."
elif [ -f "Makefile" ]; then
  LANG="makefile-project"
  BUILD_CMD="make"
  if grep -q "^test:" Makefile 2>/dev/null; then
    TEST_CMD="make test"
  fi
fi

# File tree (capped, relevant extensions only)
FILE_TREE=$(find . -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.rs" -o -name "*.go" \
  -o -name "*.vue" -o -name "*.svelte" \
  -o -name "*.java" -o -name "*.kt" -o -name "*.swift" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/target/*" \
  -not -path "*/.next/*" \
  2>/dev/null | sort | head -80)

# Entry points (common patterns)
ENTRY_POINTS=$(echo "$FILE_TREE" | grep -E "(index\.|main\.|app\.|server\.|lib\.|mod\.rs|__init__)" 2>/dev/null | head -10 || true)

# Git state
GIT_BRANCH=""
GIT_DIRTY_FILES=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  GIT_DIRTY_FILES=$(git diff --name-only 2>/dev/null | head -20)
fi

# Output as JSON (using heredoc to avoid jq dependency for generation)
cat <<JSONEOF
{
  "language": "$LANG",
  "build_cmd": "$BUILD_CMD",
  "test_cmd": "$TEST_CMD",
  "git_branch": "$GIT_BRANCH",
  "dirty_files": $(if [ -z "$GIT_DIRTY_FILES" ]; then echo "[]"; else echo "$GIT_DIRTY_FILES" | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"", $0} END{printf "]"}'; fi),
  "entry_points": $(if [ -z "$ENTRY_POINTS" ]; then echo "[]"; else echo "$ENTRY_POINTS" | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"", $0} END{printf "]"}'; fi),
  "file_count": $(if [ -z "$FILE_TREE" ]; then echo 0; else echo "$FILE_TREE" | wc -l | tr -d ' '; fi),
  "file_tree": $(if [ -z "$FILE_TREE" ]; then echo "[]"; else echo "$FILE_TREE" | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"", $0} END{printf "]"}'; fi)
}
JSONEOF
