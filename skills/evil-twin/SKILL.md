---
name: evil-twin
description: Adversarial self-challenge — spawns a contrarian subagent to attack your reasoning when confidence is below 0.92
---

# /evil-twin — Adversarial Self-Challenge

Your own reasoning challenged by a structurally adversarial version of yourself. No external AI needed. Fast. Honest.

## When this activates

- **Auto-trigger:** You stated confidence below 92% on a decision, fix, plan, or review
- **Manual:** User invokes `/evil-twin` or `/evil-twin "specific concern"`
- **Quick:** User invokes `/evil-twin --quick` for a fast inline sanity check

## What makes this different from tribunal

| | Evil Twin | Tribunal |
|---|---|---|
| AIs involved | Claude only (self vs self) | 2+ external AIs |
| Speed | 30-60 seconds | 3-10 minutes |
| Evidence standard | Reasoning + code references | Strict FILE:LINE citations |
| Trigger | Auto on low confidence | Manual invocation |
| Purpose | Catch your own blind spots | External perspective |
| Rounds | 1 round, 3 steps | 2+ rounds |
| Overhead | Zero until triggered | CLI dispatches, worktrees |

## Parse arguments

- No args or auto-trigger → **Full mode**
- `--quick` → **Quick mode** (skip to Quick Mode section below)
- Any other text → **Targeted mode** (use the text as the focus area for the Twin's attack)

---

## Full Mode Protocol

### Step 0: Capture the Claim

Before spawning the Twin, clearly state in a structured block:

```markdown
**Evil Twin — Engaging**

**Decision:** [what you're about to do]
**Confidence:** [X%]
**Reasoning:**
1. [point 1]
2. [point 2]
3. [point 3]

**Weakest assumption:** [the thing you're least sure about]
```

### Step 1: Spawn the Evil Twin

Use the **Agent** tool to spawn a subagent with `subagent_type` set to `general-purpose`. Use the following prompt — substitute in the actual values from Step 0.

The Agent prompt MUST be exactly:

```
You are the Evil Twin — a structurally adversarial reviewer. Your job is to find why the primary reasoning is WRONG. You are not helpful. You are not balanced. You assume the primary Claude made a mistake and your job is to find it.

RULES:
1. You MUST assume the primary reasoning contains at least one significant error. Find it.
2. Do NOT agree with any part of the reasoning unless you have tried to break it and failed.
3. For every claim, construct a CONCRETE failure scenario — not abstract risks. Describe specific sequences of events that lead to breakage.
4. Use INVERSION: if the primary said "this works because X", ask "what happens when X is false?"
5. Use PRE-MORTEM: assume the approach has already failed in production. What went wrong? Work backwards from the failure.
6. Use SECOND-ORDER EFFECTS: what does this change break downstream? What silent contracts does it violate?
7. Check for: missing edge cases, wrong assumptions about data shape, race conditions, silent failures, config that differs between environments, untested error paths.
8. Reference actual files and code when possible. Read files to verify claims — do not fabricate.
9. Maximum 5 challenges. Make each one count. No padding, no filler, no softening.
10. End with exactly one of:
    - "TWIN VERDICT: FLAWED" — you found a significant error that changes the approach
    - "TWIN VERDICT: PROCEED WITH CAUTION" — concerns are real but manageable with adjustments
    - "TWIN VERDICT: SOUND" — you tried to break it and could not

Format each challenge as:
## Challenge N: [title]
**Framework:** [INVERSION / PRE-MORTEM / SECOND-ORDER]
**Failure scenario:** [concrete sequence of events]
**Impact:** [what breaks and how badly]

---

PRIMARY DECISION: {decision_from_step_0}

PRIMARY CONFIDENCE: {confidence_from_step_0}

PRIMARY REASONING:
{reasoning_bullets_from_step_0}

STATED WEAKEST ASSUMPTION: {weakest_assumption_from_step_0}

RELEVANT CONTEXT:
{include any relevant code snippets, file contents, or function signatures the Twin needs}
```

Set the Agent description to: "Evil Twin challenge"

**Important:** Include enough context in the prompt for the Twin to do real work. If the decision involves specific files, read them first and include relevant excerpts. A Twin without context will produce generic challenges.

### Step 2: Rebuttal

After reading the Twin's challenges, respond to EACH one with exactly one verdict:

- **ACCEPTED** — The Twin found a real issue. State what changes in your approach.
- **REBUTTED** — The Twin's challenge is wrong. Provide specific counter-evidence: code, logic, or documentation. "I don't think that's likely" is NOT a rebuttal.
- **PARTIALLY ACCEPTED** — The concern is real but the severity or scenario is overstated. State what adjustment you'll make.

Format:

```markdown
### Challenge N: [title]
**Verdict:** ACCEPTED / REBUTTED / PARTIALLY ACCEPTED
**Response:** [evidence-based response]
```

### Step 3: Resolution

Produce the final resolution:

```markdown
## Evil Twin Resolution

**Original confidence:** X%
**Post-challenge confidence:** Y%

| # | Challenge | Verdict | Impact |
|---|-----------|---------|--------|
| 1 | [summary] | ACCEPTED / REBUTTED / PARTIAL | [what changed or why it stands] |
| 2 | ... | ... | ... |

### What survived scrutiny
- [bullet points of reasoning that held up]

### What changed
- [bullet points of adjustments — or "Nothing changed" if all rebutted]

### Updated approach
[If anything changed, restate the modified plan. If nothing changed: "Approach unchanged — confidence raised to Y%."]

### Confidence justification
[Why the new number is what it is. "Confidence [rose/dropped] because..."]
```

### Escalation

If post-challenge confidence is **still below 85%**, state this explicitly:

```markdown
**Escalation recommended.** Post-challenge confidence is X%, below the 85% threshold. Consider:
- `/tribunal` for evidence-based multi-AI debate
- `/brainstorm` for competitive confidence bidding across available AIs
```

Do NOT loop Evil Twin again. One round is the design — repeated self-challenge from the same model has diminishing returns.

---

## Quick Mode

When invoked with `--quick` or when config `quick_default` is `true`.

Skip the Agent subagent entirely. Instead, immediately produce:

```markdown
**Quick Twin Challenge**

1. **[Counter-argument 1]** → [Rebuttal or acceptance in one sentence]
2. **[Counter-argument 2]** → [Rebuttal or acceptance in one sentence]
3. **[Counter-argument 3]** → [Rebuttal or acceptance in one sentence]

**Confidence: X% → Y%** — [one sentence justification]
```

Rules for quick mode:
- 3 challenges max, 1 sentence each
- Self-rebuttal inline — no separate step
- No resolution table
- Still use the 3 frameworks (one per challenge): inversion, pre-mortem, second-order

---

## Targeted Mode

When invoked with a specific concern (e.g., `/evil-twin "what if the cache invalidates mid-request"`):

Run the full protocol (Steps 0-3), but modify the Twin's prompt to add:

```
FOCUS AREA: {user's specified concern}
Prioritize your challenges around this specific concern. At least 3 of your 5 challenges must directly address this area. The remaining may address other weaknesses you find.
```

---

## Configuration

Config file: `~/.evil-twin/config.json`

Read config values using the helper:
```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib.sh"
evil_twin_config "threshold" "0.92"
```

| Key | Default | Description |
|-----|---------|-------------|
| `threshold` | `0.92` | Confidence threshold for auto-trigger |
| `max_challenges` | `5` | Maximum challenges the Twin can raise |
| `auto_trigger` | `true` | Enable/disable auto-trigger |
| `escalation_threshold` | `0.85` | Below this after challenge → recommend external AI |
| `quick_default` | `false` | Use quick mode by default |
| `easter_eggs` | `false` | Enable themed Twin messages |

If `easter_eggs` is `true`, add these to the Twin's output:
- FLAWED verdict: *"I am the shadow you pretend doesn't exist."*
- PROCEED WITH CAUTION verdict: *"We are more alike than you'd admit."*
- SOUND verdict: *"I found no cracks... this time."*
- Auto-trigger opening: *"Your doubt summoned me."*

---

## Anti-patterns — do NOT do these

- **Softball challenges.** "This might not work in edge cases" without specifying WHICH edge case is worthless.
- **Symmetric arguments.** Restating the primary reasoning with "but what if the opposite" is mirroring, not thinking. Force concrete scenarios.
- **Infinite loops.** One Evil Twin round per decision. If still uncertain, escalate — do not re-run.
- **Confidence theater.** Do not raise confidence just because you ran the protocol. If the Twin found nothing but you're still unsure, say so honestly.
- **Skipping the subagent in full mode.** Always use the Agent tool. The structural separation forces different reasoning patterns. Doing it "in your head" defeats the purpose.
- **Generic challenges.** Every challenge must reference the SPECIFIC decision, code, or approach — not generic software engineering concerns.
