#!/usr/bin/env bash
# Evil Twin — session start hook
# Injects confidence-first reasoning rule so /evil-twin auto-triggers
# Also auto-registers Doppelganger as an AI Buddies buddy if AI Buddies is installed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

cat > /dev/null  # consume stdin (hook protocol)
AUTO_TRIGGER=$(evil_twin_config "auto_trigger" "true")
THRESHOLD=$(evil_twin_config "threshold" "0.92")

# ── AI Buddies auto-registration ─────────────────────────────────────────────
# If AI Buddies is installed, register Doppelganger as a forge-compatible buddy.
# Registration is idempotent — buddy-register.sh overwrites existing JSON.
_register_doppelganger_buddy() {
  local ai_buddies_home="${HOME}/.claudes-ai-buddies"
  local doppelganger_cli="${PLUGIN_ROOT}/scripts/doppelganger-cli.sh"

  # 1. Find buddy-register.sh — check known install locations
  local register_script=""
  # Check the plugin cache (standard Claude Code plugin install location)
  for candidate in \
    "${HOME}/.claude/plugins/cache/"*/claudes-ai-buddies/*/scripts/buddy-register.sh \
    "${HOME}/.claudes-ai-buddies/scripts/buddy-register.sh"; do
    if [[ -f "$candidate" ]]; then
      register_script="$candidate"
      break
    fi
  done

  if [[ -z "$register_script" ]]; then
    evil_twin_debug "session-start: AI Buddies not found, skipping doppelganger registration"
    return 0
  fi

  # 2. Verify doppelganger-cli.sh exists and is executable
  if [[ ! -x "$doppelganger_cli" ]]; then
    evil_twin_debug "session-start: doppelganger-cli.sh not found at $doppelganger_cli"
    return 0
  fi

  # 3. Register (idempotent)
  bash "$register_script" \
    --id "doppelganger" \
    --binary "$doppelganger_cli" \
    --display "Doppelganger (Evil Twin)" \
    --modes "exec" \
    --timeout "360" \
    --install-hint "Install evil-twin plugin: claude plugin install cukas/evil-twin" \
    >/dev/null 2>&1 || {
      evil_twin_debug "session-start: doppelganger buddy registration failed"
      return 0
    }

  evil_twin_debug "session-start: registered doppelganger as AI Buddies buddy"
  return 0
}

# Run registration in background — do not block session start
_register_doppelganger_buddy &
disown 2>/dev/null || true

if [ "$AUTO_TRIGGER" != "true" ]; then
  exit 0
fi

# ── Detect AI Buddies for enhanced instructions ──────────────────────────────
AI_BUDDIES_AVAILABLE=false
for candidate in \
  "${HOME}/.claude/plugins/cache/"*/claudes-ai-buddies/*/scripts/buddy-register.sh \
  "${HOME}/.claudes-ai-buddies/scripts/buddy-register.sh"; do
  if [[ -f "$candidate" ]]; then
    AI_BUDDIES_AVAILABLE=true
    break
  fi
done

cat <<EOF
[Evil Twin] Active — confidence-first reasoning enabled.

IMPORTANT INSTRUCTION — follow this for the entire session:

1. ALWAYS state your confidence level in every response that involves a decision, fix, review, or plan. Format: "I'm ~X% sure" or "Confidence: 0.X".
2. When your confidence is below ${THRESHOLD} (i.e., below $(echo "$THRESHOLD * 100" | bc | sed 's/\.00//')%), you MUST invoke /evil-twin before implementing. This spawns an adversarial self-challenge.
3. After the Evil Twin challenge, if confidence is still below 85%, recommend escalating to /tribunal or /brainstorm for external AI perspectives.
4. Available commands: /evil-twin (adversarial challenge), /evil-twin --quick (fast 3-point check), /doppelganger (independent blind verification in worktree).
EOF

if [[ "$AI_BUDDIES_AVAILABLE" == "true" ]]; then
  cat <<'EOF'
5. AI Buddies integration active — Doppelganger registered as a forge competitor. Additional commands:
   - /evil-pipeline "task" — full pipeline: Evil Twin challenge → brainstorm → forge with Doppelganger
   - /forge --engines doppelganger,codex,gemini — include Doppelganger as a blind competitor in forge builds
EOF
fi
