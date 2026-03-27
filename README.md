# Evil Twin

**Your shadow self. Attacks your reasoning. Solves blind. Enters the forge.**

Works standalone with just Claude. Connects into [AI Buddies](https://github.com/cukas/claudes-ai-buddies) for full multi-AI competitive builds.

## What's inside

| Command | What it does | Speed |
|---------|-------------|-------|
| `/evil-twin` | Adversarial self-challenge — assumes you're wrong, finds the error | 30-60s |
| `/evil-twin --quick` | Fast inline 3-point sanity check | 5-10s |
| `/doppelganger` | Independent blind solve in git worktree — merges best of both | 2-5 min |
| `/evil-pipeline` | Full chain: Twin → brainstorm → forge with Doppelganger | 5-15 min |

## Install

```bash
claude plugin marketplace add cukas-evil-twin --source github --repo cukas/evil-twin
claude plugin install evil-twin@cukas-evil-twin
```

If you have [AI Buddies](https://github.com/cukas/claudes-ai-buddies) installed, Doppelganger auto-registers as a forge competitor on session start.

## How it works

### Evil Twin — "Am I wrong?"

Auto-triggers when Claude states confidence below 92%. A second Claude with an adversarial system prompt attacks your reasoning using three frameworks:

- **Inversion** — "You said X works because Y. What if Y is false?"
- **Pre-mortem** — "This shipped and broke production. What went wrong?"
- **Second-order** — "What does this break downstream?"

Up to 5 concrete failure scenarios. You rebuttal each one. Resolution table with updated confidence. If still below 85% → escalates to `/tribunal` or `/brainstorm`.

### Doppelganger — "Is there a better way?"

A second Claude solves the same problem in a git worktree WITHOUT seeing your solution. Then both approaches are compared. **Merges the best parts from both** — doesn't just pick a winner.

Includes programmatic leakage detection to verify independence.

### Evil Pipeline — "Go full send"

Chains everything together when stakes are high:

```
/evil-pipeline "implement auth middleware"

  1. Evil Twin challenges your approach          (30-60s)
     |
  2. Brainstorm/tribunal if still uncertain      (3-5 min)
     |
  3. Forge: Doppelganger + Codex + Gemini        (3-10 min)
     |    Doppelganger solves BLIND (no context from steps 1-2)
     |    Codex and Gemini solve independently
     |
  4. Convergence analysis + merge best parts
```

The key insight: in regular `/forge`, Claude has seen the entire conversation (unfair anchoring). Doppelganger replaces Claude's slot with a genuinely blind solve — like Codex and Gemini, it starts fresh.

Requires [AI Buddies](https://github.com/cukas/claudes-ai-buddies) plugin.

## When to use what

| Situation | Tool |
|-----------|------|
| "Am I wrong about this?" | `/evil-twin` |
| Quick sanity check | `/evil-twin --quick` |
| "Is there a better way?" | `/doppelganger` |
| High-stakes, need full verification | `/evil-pipeline` |
| External perspectives needed | `/tribunal` (AI Buddies) |
| Who should take this task? | `/brainstorm` (AI Buddies) |

## Configuration

Config file: `~/.evil-twin/config.json`

```json
{
  "threshold": 0.92,
  "max_challenges": 5,
  "auto_trigger": true,
  "escalation_threshold": 0.85,
  "quick_default": false,
  "easter_eggs": false,
  "doppelganger_timeout": 300,
  "doppelganger_run_tests": true,
  "doppelganger_run_build": true,
  "pipeline_stop_on_flawed": true,
  "pipeline_timeout": 600
}
```

## Architecture

```
evil-twin/
├── skills/
│   ├── evil-twin/SKILL.md        # Adversarial challenge protocol
│   ├── doppelganger/SKILL.md     # Blind verification protocol
│   └── evil-pipeline/SKILL.md    # Full pipeline orchestration
├── scripts/
│   ├── doppelganger-cli.sh       # CLI adapter for AI Buddies forge
│   ├── detect-project.sh         # Auto-detect language, build, test
│   └── leakage-check.sh          # Contamination detection
├── hooks/
│   ├── session-start.sh          # Confidence injection + buddy registration
│   └── lib.sh                    # Config helpers
└── commands/
    ├── evil-twin-help.md
    └── evil-twin-config.md
```

**Standalone:** Works with just Claude. No external AI keys needed.
**Connected:** If AI Buddies is installed, Doppelganger auto-registers as a forge competitor. `/evil-pipeline` chains everything together.

## License

MIT
