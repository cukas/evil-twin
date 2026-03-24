#!/usr/bin/env bash
# Evil Twin — test suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() { ((PASS++)); ((TOTAL++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  FAIL: $1 — $2"; }

echo "Evil Twin — Test Suite"
echo "======================"
echo ""

# --------------------------------------------------
# 1. Plugin structure
# --------------------------------------------------
echo "## Structure"

[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ] \
  && pass "plugin.json exists" \
  || fail "plugin.json exists" "missing"

[ -f "$PLUGIN_ROOT/.claude-plugin/marketplace.json" ] \
  && pass "marketplace.json exists" \
  || fail "marketplace.json exists" "missing"

[ -f "$PLUGIN_ROOT/hooks/hooks.json" ] \
  && pass "hooks.json exists" \
  || fail "hooks.json exists" "missing"

[ -f "$PLUGIN_ROOT/hooks/lib.sh" ] \
  && pass "lib.sh exists" \
  || fail "lib.sh exists" "missing"

[ -x "$PLUGIN_ROOT/hooks/lib.sh" ] \
  && pass "lib.sh is executable" \
  || fail "lib.sh is executable" "not executable"

[ -f "$PLUGIN_ROOT/skills/evil-twin/SKILL.md" ] \
  && pass "SKILL.md exists" \
  || fail "SKILL.md exists" "missing"

[ -f "$PLUGIN_ROOT/commands/evil-twin-help.md" ] \
  && pass "evil-twin-help.md exists" \
  || fail "evil-twin-help.md exists" "missing"

[ -f "$PLUGIN_ROOT/commands/evil-twin-config.md" ] \
  && pass "evil-twin-config.md exists" \
  || fail "evil-twin-config.md exists" "missing"

[ -f "$PLUGIN_ROOT/README.md" ] \
  && pass "README.md exists" \
  || fail "README.md exists" "missing"

[ -f "$PLUGIN_ROOT/LICENSE" ] \
  && pass "LICENSE exists" \
  || fail "LICENSE exists" "missing"

[ -f "$PLUGIN_ROOT/CHANGELOG.md" ] \
  && pass "CHANGELOG.md exists" \
  || fail "CHANGELOG.md exists" "missing"

echo ""

# --------------------------------------------------
# 2. JSON validity
# --------------------------------------------------
echo "## JSON Validity"

jq empty "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null \
  && pass "plugin.json is valid JSON" \
  || fail "plugin.json is valid JSON" "parse error"

jq empty "$PLUGIN_ROOT/.claude-plugin/marketplace.json" 2>/dev/null \
  && pass "marketplace.json is valid JSON" \
  || fail "marketplace.json is valid JSON" "parse error"

jq empty "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null \
  && pass "hooks.json is valid JSON" \
  || fail "hooks.json is valid JSON" "parse error"

echo ""

# --------------------------------------------------
# 3. plugin.json fields
# --------------------------------------------------
echo "## plugin.json Fields"

NAME=$(jq -r '.name' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
[ "$NAME" = "evil-twin" ] \
  && pass "plugin name is 'evil-twin'" \
  || fail "plugin name" "got '$NAME'"

AUTHOR=$(jq -r '.author.name' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
[ "$AUTHOR" = "cukas" ] \
  && pass "author is 'cukas'" \
  || fail "author" "got '$AUTHOR'"

VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  && pass "version is semver ($VERSION)" \
  || fail "version semver" "got '$VERSION'"

LICENSE_FIELD=$(jq -r '.license' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
[ "$LICENSE_FIELD" = "MIT" ] \
  && pass "license is MIT" \
  || fail "license" "got '$LICENSE_FIELD'"

echo ""

# --------------------------------------------------
# 4. marketplace.json consistency
# --------------------------------------------------
echo "## Marketplace Consistency"

MP_NAME=$(jq -r '.plugins[0].name' "$PLUGIN_ROOT/.claude-plugin/marketplace.json")
[ "$MP_NAME" = "$NAME" ] \
  && pass "marketplace plugin name matches plugin.json" \
  || fail "marketplace name mismatch" "'$MP_NAME' vs '$NAME'"

MP_VERSION=$(jq -r '.plugins[0].version' "$PLUGIN_ROOT/.claude-plugin/marketplace.json")
[ "$MP_VERSION" = "$VERSION" ] \
  && pass "marketplace version matches plugin.json" \
  || fail "marketplace version mismatch" "'$MP_VERSION' vs '$VERSION'"

echo ""

# --------------------------------------------------
# 5. SKILL.md frontmatter
# --------------------------------------------------
echo "## SKILL.md Frontmatter"

FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$PLUGIN_ROOT/skills/evil-twin/SKILL.md")

echo "$FRONTMATTER" | grep -q "^name:" \
  && pass "SKILL.md has 'name' field" \
  || fail "SKILL.md frontmatter" "missing 'name'"

echo "$FRONTMATTER" | grep -q "^description:" \
  && pass "SKILL.md has 'description' field" \
  || fail "SKILL.md frontmatter" "missing 'description'"

SKILL_NAME=$(echo "$FRONTMATTER" | grep "^name:" | sed 's/name: *//')
[ "$SKILL_NAME" = "evil-twin" ] \
  && pass "SKILL.md name matches plugin name" \
  || fail "SKILL.md name" "got '$SKILL_NAME'"

echo ""

# --------------------------------------------------
# 6. Command frontmatter
# --------------------------------------------------
echo "## Command Frontmatter"

for cmd in evil-twin-help evil-twin-config; do
  CMD_FILE="$PLUGIN_ROOT/commands/${cmd}.md"
  CMD_FM=$(sed -n '/^---$/,/^---$/p' "$CMD_FILE")

  echo "$CMD_FM" | grep -q "^name:" \
    && pass "${cmd}.md has 'name' field" \
    || fail "${cmd}.md frontmatter" "missing 'name'"

  echo "$CMD_FM" | grep -q "^description:" \
    && pass "${cmd}.md has 'description' field" \
    || fail "${cmd}.md frontmatter" "missing 'description'"
done

echo ""

# --------------------------------------------------
# 7. Hooks
# --------------------------------------------------
echo "## Hooks"

jq -e '.hooks.SessionStart' "$PLUGIN_ROOT/hooks/hooks.json" >/dev/null 2>&1 \
  && pass "hooks.json defines SessionStart hook" \
  || fail "hooks.json" "missing SessionStart hook"

[ -f "$PLUGIN_ROOT/hooks/session-start.sh" ] \
  && pass "session-start.sh exists" \
  || fail "session-start.sh exists" "missing"

[ -x "$PLUGIN_ROOT/hooks/session-start.sh" ] \
  && pass "session-start.sh is executable" \
  || fail "session-start.sh is executable" "not executable"

bash -n "$PLUGIN_ROOT/hooks/session-start.sh" 2>/dev/null \
  && pass "session-start.sh has valid syntax" \
  || fail "session-start.sh syntax" "parse error"

grep -q "confidence" "$PLUGIN_ROOT/hooks/session-start.sh" \
  && pass "session-start.sh injects confidence rule" \
  || fail "session-start.sh" "missing confidence injection"

grep -q "evil-twin" "$PLUGIN_ROOT/hooks/session-start.sh" \
  && pass "session-start.sh references /evil-twin" \
  || fail "session-start.sh" "missing /evil-twin reference"

echo ""

# --------------------------------------------------
# 8. lib.sh functions
# --------------------------------------------------
echo "## lib.sh Functions"

bash -n "$PLUGIN_ROOT/hooks/lib.sh" 2>/dev/null \
  && pass "lib.sh has valid bash syntax" \
  || fail "lib.sh syntax" "parse error"

grep -q "evil_twin_config()" "$PLUGIN_ROOT/hooks/lib.sh" \
  && pass "lib.sh defines evil_twin_config()" \
  || fail "lib.sh" "missing evil_twin_config()"

grep -q "evil_twin_debug()" "$PLUGIN_ROOT/hooks/lib.sh" \
  && pass "lib.sh defines evil_twin_debug()" \
  || fail "lib.sh" "missing evil_twin_debug()"

grep -q "evil_twin_require_jq()" "$PLUGIN_ROOT/hooks/lib.sh" \
  && pass "lib.sh defines evil_twin_require_jq()" \
  || fail "lib.sh" "missing evil_twin_require_jq()"

echo ""

# --------------------------------------------------
# 9. lib.sh config reader (functional test)
# --------------------------------------------------
echo "## lib.sh Config Reader"

# Test default when no config exists
source "$PLUGIN_ROOT/hooks/lib.sh"
EVIL_TWIN_CONFIG_DIR=$(mktemp -d)

RESULT=$(evil_twin_config "threshold" "0.92")
[ "$RESULT" = "0.92" ] \
  && pass "returns default when no config file" \
  || fail "default config" "got '$RESULT'"

# Test reading from config file
echo '{"threshold": "0.88", "auto_trigger": true}' > "$EVIL_TWIN_CONFIG_DIR/config.json"

RESULT=$(evil_twin_config "threshold" "0.92")
[ "$RESULT" = "0.88" ] \
  && pass "reads threshold from config file" \
  || fail "config read" "got '$RESULT'"

RESULT=$(evil_twin_config "missing_key" "fallback")
[ "$RESULT" = "fallback" ] \
  && pass "returns default for missing key" \
  || fail "missing key fallback" "got '$RESULT'"

rm -rf "$EVIL_TWIN_CONFIG_DIR"

echo ""

# --------------------------------------------------
# 10. Scripts
# --------------------------------------------------
echo "## Scripts"

[ -f "$PLUGIN_ROOT/scripts/detect-project.sh" ] \
  && pass "detect-project.sh exists" \
  || fail "detect-project.sh exists" "missing"

[ -x "$PLUGIN_ROOT/scripts/detect-project.sh" ] \
  && pass "detect-project.sh is executable" \
  || fail "detect-project.sh is executable" "not executable"

bash -n "$PLUGIN_ROOT/scripts/detect-project.sh" 2>/dev/null \
  && pass "detect-project.sh has valid syntax" \
  || fail "detect-project.sh syntax" "parse error"

[ -f "$PLUGIN_ROOT/scripts/leakage-check.sh" ] \
  && pass "leakage-check.sh exists" \
  || fail "leakage-check.sh exists" "missing"

[ -x "$PLUGIN_ROOT/scripts/leakage-check.sh" ] \
  && pass "leakage-check.sh is executable" \
  || fail "leakage-check.sh is executable" "not executable"

bash -n "$PLUGIN_ROOT/scripts/leakage-check.sh" 2>/dev/null \
  && pass "leakage-check.sh has valid syntax" \
  || fail "leakage-check.sh syntax" "parse error"

# Functional test: detect-project against this repo
DETECT_OUTPUT=$(bash "$PLUGIN_ROOT/scripts/detect-project.sh" "$PLUGIN_ROOT" 2>/dev/null)
echo "$DETECT_OUTPUT" | jq empty 2>/dev/null \
  && pass "detect-project.sh outputs valid JSON" \
  || fail "detect-project.sh JSON" "invalid output"

echo "$DETECT_OUTPUT" | jq -e '.language' >/dev/null 2>&1 \
  && pass "detect-project.sh includes language field" \
  || fail "detect-project.sh" "missing language"

echo "$DETECT_OUTPUT" | jq -e '.build_cmd' >/dev/null 2>&1 \
  && pass "detect-project.sh includes build_cmd field" \
  || fail "detect-project.sh" "missing build_cmd"

echo "$DETECT_OUTPUT" | jq -e '.test_cmd' >/dev/null 2>&1 \
  && pass "detect-project.sh includes test_cmd field" \
  || fail "detect-project.sh" "missing test_cmd"

echo "$DETECT_OUTPUT" | jq -e '.file_tree' >/dev/null 2>&1 \
  && pass "detect-project.sh includes file_tree field" \
  || fail "detect-project.sh" "missing file_tree"

echo "$DETECT_OUTPUT" | jq -e '.git_branch' >/dev/null 2>&1 \
  && pass "detect-project.sh includes git_branch field" \
  || fail "detect-project.sh" "missing git_branch"

echo ""

# --------------------------------------------------
# 11. Doppelganger structure
# --------------------------------------------------
echo "## Doppelganger Structure"

[ -f "$PLUGIN_ROOT/skills/doppelganger/SKILL.md" ] \
  && pass "doppelganger SKILL.md exists" \
  || fail "doppelganger SKILL.md exists" "missing"

DOPPEL_FM=$(sed -n '/^---$/,/^---$/p' "$PLUGIN_ROOT/skills/doppelganger/SKILL.md")

echo "$DOPPEL_FM" | grep -q "^name:" \
  && pass "doppelganger SKILL.md has 'name' field" \
  || fail "doppelganger SKILL.md frontmatter" "missing 'name'"

echo "$DOPPEL_FM" | grep -q "^description:" \
  && pass "doppelganger SKILL.md has 'description' field" \
  || fail "doppelganger SKILL.md frontmatter" "missing 'description'"

DOPPEL_NAME=$(echo "$DOPPEL_FM" | grep "^name:" | sed 's/name: *//')
[ "$DOPPEL_NAME" = "doppelganger" ] \
  && pass "doppelganger SKILL.md name is 'doppelganger'" \
  || fail "doppelganger SKILL.md name" "got '$DOPPEL_NAME'"

echo ""

# --------------------------------------------------
# 11. Doppelganger content checks
# --------------------------------------------------
echo "## Doppelganger Content"

DOPPEL="$PLUGIN_ROOT/skills/doppelganger/SKILL.md"

grep -q "worktree" "$DOPPEL" \
  && pass "doppelganger references worktree isolation" \
  || fail "doppelganger" "missing worktree reference"

grep -q "isolation" "$DOPPEL" \
  && pass "doppelganger references isolation parameter" \
  || fail "doppelganger" "missing isolation parameter"

grep -q "Leakage" "$DOPPEL" \
  && pass "doppelganger includes leakage check" \
  || fail "doppelganger" "missing leakage check"

grep -q "Convergence" "$DOPPEL" \
  && pass "doppelganger includes convergence analysis" \
  || fail "doppelganger" "missing convergence"

grep -q "Divergence" "$DOPPEL" \
  && pass "doppelganger includes divergence analysis" \
  || fail "doppelganger" "missing divergence"

grep -q "Doppelganger-only" "$DOPPEL" \
  && pass "doppelganger includes missed-opportunity section" \
  || fail "doppelganger" "missing Doppelganger-only findings"

grep -q "Assumptions" "$DOPPEL" \
  && pass "doppelganger includes assumption documentation" \
  || fail "doppelganger" "missing assumptions"

grep -q "Quick" "$DOPPEL" \
  && pass "doppelganger includes quick mode" \
  || fail "doppelganger" "missing quick mode"

grep -q "Agent" "$DOPPEL" \
  && pass "doppelganger references Agent tool" \
  || fail "doppelganger" "missing Agent tool reference"

grep -q "Anti-patterns" "$DOPPEL" \
  && pass "doppelganger includes anti-patterns" \
  || fail "doppelganger" "missing anti-patterns"

echo ""

# --------------------------------------------------
# 12. Evil Twin SKILL.md content checks
# --------------------------------------------------
echo "## Evil Twin SKILL.md Content"

SKILL="$PLUGIN_ROOT/skills/evil-twin/SKILL.md"

grep -q "Evil Twin" "$SKILL" \
  && pass "SKILL.md mentions Evil Twin" \
  || fail "SKILL.md" "missing Evil Twin reference"

grep -q "Agent" "$SKILL" \
  && pass "SKILL.md references Agent tool" \
  || fail "SKILL.md" "missing Agent tool reference"

grep -q "INVERSION" "$SKILL" \
  && pass "SKILL.md includes INVERSION framework" \
  || fail "SKILL.md" "missing INVERSION"

grep -q "PRE-MORTEM" "$SKILL" \
  && pass "SKILL.md includes PRE-MORTEM framework" \
  || fail "SKILL.md" "missing PRE-MORTEM"

grep -q "SECOND-ORDER" "$SKILL" \
  && pass "SKILL.md includes SECOND-ORDER framework" \
  || fail "SKILL.md" "missing SECOND-ORDER"

grep -q "TWIN VERDICT" "$SKILL" \
  && pass "SKILL.md includes TWIN VERDICT" \
  || fail "SKILL.md" "missing TWIN VERDICT"

grep -q "Quick Mode" "$SKILL" \
  && pass "SKILL.md includes Quick Mode" \
  || fail "SKILL.md" "missing Quick Mode"

grep -q "Targeted Mode" "$SKILL" \
  && pass "SKILL.md includes Targeted Mode" \
  || fail "SKILL.md" "missing Targeted Mode"

grep -q "escalation" "$SKILL" \
  && pass "SKILL.md includes escalation path" \
  || fail "SKILL.md" "missing escalation"

grep -q "Anti-patterns" "$SKILL" \
  && pass "SKILL.md includes anti-patterns" \
  || fail "SKILL.md" "missing anti-patterns"

echo ""

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo "======================"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
echo ""

[ "$FAIL" -eq 0 ] && echo "ALL TESTS PASSED" && exit 0
echo "SOME TESTS FAILED" && exit 1
