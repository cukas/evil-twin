# Evil Twin

**Your shadow self. Two modes: one attacks, one independently verifies. Claude-only.**

No external AI keys needed. No setup. Just better reasoning.

## Two Modes

### `/evil-twin` — Adversarial Self-Challenge
When confidence drops below 92%, a second Claude assumes you're wrong and attacks your reasoning. Fast (30-60s), lightweight, honest.

### `/doppelganger` — Independent Blind Verification
A second Claude solves the same problem in a git worktree WITHOUT seeing your solution. Then both approaches are compared. Convergence = ship it. Divergence = the real design decision.

## Why

| | Evil Twin | Doppelganger | Tribunal |
|---|---|---|---|
| AIs needed | Claude only | Claude only | 2+ external |
| Sees your solution? | Yes (attacks it) | No (solves blind) | Yes (debates it) |
| Produces code? | No | Yes (in worktree) | No |
| Speed | 30-60 seconds | 2-5 minutes | 3-10 minutes |
| Setup | Zero | Zero | API keys required |

## Install

```bash
claude /plugin install evil-twin@cukas
```

## Usage

### Evil Twin (adversarial)
```
/evil-twin                          # Full adversarial challenge
/evil-twin --quick                  # Fast inline 3-challenge check
/evil-twin "cache invalidation"     # Targeted challenge on specific area
```

### Doppelganger (independent verification)
```
/doppelganger                       # Independent blind solve in worktree
/doppelganger --quick               # Plan-level comparison (no worktree)
/doppelganger "add auth middleware"  # Solve this problem independently
```

## How Evil Twin works

1. **Capture** — Claude states its decision, confidence, reasoning, and weakest assumption
2. **Attack** — A subagent with adversarial prompt finds up to 5 concrete failure scenarios
3. **Rebuttal** — Claude responds: ACCEPTED, REBUTTED, or PARTIALLY ACCEPTED
4. **Resolution** — Summary table with updated confidence

## How Doppelganger works

1. **Freeze** — Separate problem from solution. Solution stays hidden.
2. **Blind solve** — Subagent spawns in a git worktree with only the problem. Writes code, runs build + tests.
3. **Leakage check** — Verify the Doppelganger didn't accidentally see the primary's solution.
4. **Compare** — Convergence (agreed), divergence (different approaches), missed opportunities.
5. **Verdict** — HIGH (ship it), MODERATE (review divergence), LOW (escalate).

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
  "doppelganger_run_build": true
}
```

## License

MIT
