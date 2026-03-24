#!/usr/bin/env bash
# Evil Twin — Doppelganger leakage detection
# Compares primary's modified files against Doppelganger's worktree activity
# Usage: leakage-check.sh <primary_branch> <doppelganger_branch> [base_ref]
set -euo pipefail

PRIMARY_BRANCH="${1:?Usage: leakage-check.sh <primary_branch> <doppelganger_branch> [base_ref]}"
DOPPEL_BRANCH="${2:?Usage: leakage-check.sh <primary_branch> <doppelganger_branch> [base_ref]}"
BASE_REF="${3:-HEAD~1}"

LEAKAGE_FOUND=false
WARNINGS=()

# 1. Files the primary modified
PRIMARY_FILES=$(git diff --name-only "$BASE_REF" "$PRIMARY_BRANCH" 2>/dev/null | sort)
if [ -z "$PRIMARY_FILES" ]; then
  echo '{"status": "skip", "reason": "no primary changes detected", "warnings": []}'
  exit 0
fi

# 2. Files the Doppelganger modified
DOPPEL_FILES=$(git diff --name-only "$BASE_REF" "$DOPPEL_BRANCH" 2>/dev/null | sort)

# 3. Check: did Doppelganger modify the EXACT same files?
OVERLAP=$(comm -12 <(echo "$PRIMARY_FILES") <(echo "$DOPPEL_FILES"))
OVERLAP_COUNT=$(echo "$OVERLAP" | grep -c . || echo 0)
PRIMARY_COUNT=$(echo "$PRIMARY_FILES" | grep -c . || echo 0)
DOPPEL_COUNT=$(echo "$DOPPEL_FILES" | grep -c . || echo 0)

# High overlap on non-obvious files is suspicious
if [ "$OVERLAP_COUNT" -gt 0 ]; then
  # Check if overlapping files are "obvious" targets (entry points, config)
  SUSPICIOUS_OVERLAP=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Entry points and config files are expected to overlap
    if echo "$file" | grep -qvE "(index\.|main\.|app\.|config\.|package\.json|Cargo\.toml|pyproject\.toml)"; then
      SUSPICIOUS_OVERLAP="$SUSPICIOUS_OVERLAP$file\n"
    fi
  done <<< "$OVERLAP"

  if [ -n "$SUSPICIOUS_OVERLAP" ]; then
    WARNINGS+=("suspicious_file_overlap: Doppelganger modified non-obvious files that primary also modified: $(echo -e "$SUSPICIOUS_OVERLAP" | tr '\n' ', ')")
  fi
fi

# 4. Check for identical hunks (line-level convergence on non-trivial code)
IDENTICAL_HUNKS=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  PRIMARY_DIFF=$(git diff "$BASE_REF" "$PRIMARY_BRANCH" -- "$file" 2>/dev/null | grep "^+" | grep -v "^+++" | sort)
  DOPPEL_DIFF=$(git diff "$BASE_REF" "$DOPPEL_BRANCH" -- "$file" 2>/dev/null | grep "^+" | grep -v "^+++" | sort)

  if [ -n "$PRIMARY_DIFF" ] && [ -n "$DOPPEL_DIFF" ]; then
    # Find identical added lines (excluding trivial ones like imports, braces)
    IDENTICAL=$(comm -12 <(echo "$PRIMARY_DIFF" | grep -vE '^\+\s*(import |from |require\(|\{|\}|$)') \
                         <(echo "$DOPPEL_DIFF" | grep -vE '^\+\s*(import |from |require\(|\{|\}|$)') 2>/dev/null)
    if [ -n "$IDENTICAL" ]; then
      COUNT=$(echo "$IDENTICAL" | grep -c . || echo 0)
      if [ "$COUNT" -gt 3 ]; then
        IDENTICAL_HUNKS=$((IDENTICAL_HUNKS + COUNT))
        WARNINGS+=("identical_code in $file: $COUNT non-trivial lines identical between primary and Doppelganger")
        LEAKAGE_FOUND=true
      fi
    fi
  fi
done <<< "$OVERLAP"

# 5. Check for unique identifiers from primary appearing in Doppelganger
# Extract new function/variable names introduced by primary
PRIMARY_NEW_NAMES=$(git diff "$BASE_REF" "$PRIMARY_BRANCH" 2>/dev/null \
  | grep "^+" | grep -v "^+++" \
  | grep -oE '\b(function|const|let|var|def|fn|func)\s+[a-zA-Z_][a-zA-Z0-9_]*' \
  | awk '{print $2}' | sort -u)

if [ -n "$PRIMARY_NEW_NAMES" ]; then
  DOPPEL_FULL_DIFF=$(git diff "$BASE_REF" "$DOPPEL_BRANCH" 2>/dev/null | grep "^+" | grep -v "^+++")
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    # Skip common/generic names
    echo "$name" | grep -qE "^(main|init|setup|run|test|handle|get|set|update|create|delete|fetch|load|save|process|render|build|start|stop)$" && continue
    if echo "$DOPPEL_FULL_DIFF" | grep -q "\b$name\b" 2>/dev/null; then
      WARNINGS+=("name_collision: primary introduced '$name' and Doppelganger also used it — may indicate leakage or convergent naming")
    fi
  done <<< "$PRIMARY_NEW_NAMES"
fi

# 6. Verdict
STATUS="clean"
if [ "$LEAKAGE_FOUND" = true ]; then
  STATUS="contaminated"
elif [ "${#WARNINGS[@]}" -gt 0 ]; then
  STATUS="warning"
fi

# Output JSON
echo "{"
echo "  \"status\": \"$STATUS\","
echo "  \"primary_files_changed\": $PRIMARY_COUNT,"
echo "  \"doppelganger_files_changed\": $DOPPEL_COUNT,"
echo "  \"file_overlap\": $OVERLAP_COUNT,"
echo "  \"identical_hunks\": $IDENTICAL_HUNKS,"
echo "  \"warnings\": ["
for i in "${!WARNINGS[@]}"; do
  COMMA=""
  [ "$i" -lt $((${#WARNINGS[@]} - 1)) ] && COMMA=","
  echo "    \"${WARNINGS[$i]}\"$COMMA"
done
echo "  ]"
echo "}"
