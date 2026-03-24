#!/usr/bin/env bash
# Evil Twin — session start hook
# Injects confidence-first reasoning rule so /evil-twin auto-triggers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

cat > /dev/null  # consume stdin (hook protocol)
AUTO_TRIGGER=$(evil_twin_config "auto_trigger" "true")
THRESHOLD=$(evil_twin_config "threshold" "0.92")

if [ "$AUTO_TRIGGER" != "true" ]; then
  exit 0
fi

cat <<EOF
[Evil Twin] Active — confidence-first reasoning enabled.

IMPORTANT INSTRUCTION — follow this for the entire session:

1. ALWAYS state your confidence level in every response that involves a decision, fix, review, or plan. Format: "I'm ~X% sure" or "Confidence: 0.X".
2. When your confidence is below ${THRESHOLD} (i.e., below $(echo "$THRESHOLD * 100" | bc | sed 's/\.00//')%), you MUST invoke /evil-twin before implementing. This spawns an adversarial self-challenge.
3. After the Evil Twin challenge, if confidence is still below 85%, recommend escalating to /tribunal or /brainstorm for external AI perspectives.
4. Available commands: /evil-twin (adversarial challenge), /evil-twin --quick (fast 3-point check), /doppelganger (independent blind verification in worktree).
EOF
