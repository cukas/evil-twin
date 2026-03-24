---
name: evil-twin-help
description: Reference for the Evil Twin plugin — adversarial self-challenge + independent blind verification
---

# Evil Twin — Help & Reference

Your shadow self. Two modes: one attacks your reasoning, one independently verifies it. Claude-only. No external AI needed.

Show the user this reference:

## Commands

| Command | Description |
|---------|-------------|
| `/evil-twin` | Adversarial self-challenge (spawns contrarian subagent) |
| `/evil-twin --quick` | Quick inline 3-challenge sanity check |
| `/evil-twin "concern"` | Targeted challenge on a specific area |
| `/doppelganger` | Independent blind solve in a git worktree |
| `/doppelganger --quick` | Plan-level comparison (no worktree, no code) |
| `/evil-twin-config` | Show or edit configuration |
| `/evil-twin-help` | This help reference |

## How it works

```
Confidence < 92% (auto) or user invokes /evil-twin

  Step 0: Primary states reasoning + confidence + weakest point
    |
  Step 1: Agent subagent spawned with adversarial prompt
    |        - Assumes primary is WRONG
    |        - 3 frameworks: inversion, pre-mortem, second-order
    |        - Up to 5 concrete failure scenarios
    |        - Verdict: FLAWED / PROCEED WITH CAUTION / SOUND
    |
  Step 2: Primary rebuts each challenge
    |        - ACCEPTED / REBUTTED / PARTIALLY ACCEPTED
    |
  Step 3: Resolution table + updated confidence
    |
    +-- If still < 85% → recommend /tribunal or /brainstorm
```

## Quick mode

Skips the subagent. 3 inline counter-arguments with immediate self-rebuttal. Use when you want a fast sanity check, not the full protocol.

## Modes comparison

| Mode | Speed | Depth | When to use |
|------|-------|-------|-------------|
| Evil Twin (full) | 30-60s | Deep (5 challenges) | Default. Confidence 70-91% |
| Evil Twin (quick) | 5-10s | Light (3 inline) | Fast sanity check. Minor uncertainty |
| Evil Twin (targeted) | 30-60s | Focused | User has a specific worry |
| Doppelganger (full) | 2-5 min | Code + build + test in worktree | High-risk changes, architecture decisions |
| Doppelganger (quick) | 30-60s | Plan-level comparison | Fast approach validation |

## Doppelganger — how it works

```
User invokes /doppelganger "problem description"

  Step 0: Primary freezes problem vs solution (solution stays hidden)
    |
  Step 1: Doppelganger spawned in git worktree (clean HEAD state)
    |        - Sees ONLY the problem, NOT your solution
    |        - Writes actual code, runs build + tests
    |        - Documents assumptions and design decisions
    |
  Step 2: Leakage check (did it accidentally see your changes?)
    |
  Step 3: Structured comparison
    |        - Convergence (both agreed = high confidence)
    |        - Divergence (different approaches = the real decision)
    |        - Primary-only / Doppelganger-only findings
    |
  Step 4: Verdict
           HIGH (7-10) → ship it
           MODERATE (4-6) → review divergence points
           LOW (0-3) → escalate to /tribunal
```

## Config

File: `~/.evil-twin/config.json`

| Setting | Default | Description |
|---------|---------|-------------|
| `threshold` | `0.92` | Auto-trigger confidence threshold |
| `max_challenges` | `5` | Max challenges per Twin session |
| `auto_trigger` | `true` | Enable auto-trigger on low confidence |
| `escalation_threshold` | `0.85` | Recommend external AI below this |
| `quick_default` | `false` | Use quick mode by default |
| `easter_eggs` | `false` | Enable themed Twin messages |

## When to use what

| Situation | Tool |
|-----------|------|
| "Am I wrong about this?" | `/evil-twin` |
| "Is there a better way I didn't see?" | `/doppelganger` |
| "I need external perspectives" | `/tribunal` (needs API keys) |
| "Who should take this task?" | `/brainstorm` (needs API keys) |
| "Build it competitively" | `/forge` (needs API keys) |

## Relationship to other tools

- **Evil Twin** — Attacks your reasoning. Fast. Claude-only.
- **Doppelganger** — Solves blind, then compares. Thorough. Claude-only.
- **Tribunal** — Multi-AI debate. External perspectives. Needs API keys.
- **Brainstorm** — Multi-AI bidding. Picks who's best. Needs API keys.
- **Forge** — Multi-AI competitive build. Actual code. Needs API keys.
