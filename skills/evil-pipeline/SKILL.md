---
name: evil-pipeline
description: Full adversarial pipeline — Evil Twin challenge, then brainstorm/tribunal, then forge with Doppelganger as blind competitor
---

# /evil-pipeline — Adversarial Build Pipeline

Chains Evil Twin's adversarial reasoning with AI Buddies' competitive build system. The Doppelganger enters forge as a blind competitor — solving the same task without seeing your approach.

## Requirements

- **Evil Twin plugin** (this plugin) — provides /evil-twin and /doppelganger
- **AI Buddies plugin** — provides /forge, /brainstorm, /tribunal
- If AI Buddies is not installed, this skill will error with instructions to install it.

## When to use this

- High-stakes implementation where you want BOTH adversarial reasoning AND competitive verification
- Architecture decisions where multiple valid approaches exist
- When the user says "go full pipeline" or "evil-pipeline this"
- NOT for trivial fixes — this takes 5-15 minutes and dispatches multiple AIs

## Parse arguments

- `/evil-pipeline "task description"` — run the full pipeline on this task
- `/evil-pipeline --skip-twin "task"` — skip the Evil Twin step, go straight to brainstorm + forge
- `/evil-pipeline --skip-brainstorm "task"` — skip brainstorm, go Twin + forge only
- No args → prompt user: "What task should the evil pipeline run?"

---

## Protocol

### Step 0: Preflight — Verify AI Buddies is installed

Before doing anything, verify AI Buddies is available:

```bash
# Check if AI Buddies buddy-register.sh exists
REGISTER_SCRIPT=""
for candidate in \
  "${HOME}/.claude/plugins/cache/"*/claudes-ai-buddies/*/scripts/buddy-register.sh \
  "${HOME}/.claudes-ai-buddies/scripts/buddy-register.sh"; do
  [ -f "$candidate" ] && REGISTER_SCRIPT="$candidate" && break
done
```

If `REGISTER_SCRIPT` is empty, stop and tell the user:

```markdown
**Evil Pipeline requires AI Buddies.** Install it:
```
claude plugin install cukas/claudes-ai-buddies
```
Then re-run /evil-pipeline.
```

Also verify the doppelganger buddy is registered:

```bash
ls "${HOME}/.claudes-ai-buddies/buddies/doppelganger.json" 2>/dev/null
```

If not found, register it now:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doppelganger-cli.sh" --help 2>/dev/null || echo "MISSING"
```

If doppelganger-cli.sh exists but is not registered, run the session-start hook's registration logic manually — this is a one-time recovery. The buddy registration is normally automatic on session start.

### Step 1: Capture the Task

Parse the user's task and clearly state:

```markdown
**Evil Pipeline — Initiated**

**Task:** [the user's request]
**Skip Twin:** [yes/no]
**Skip Brainstorm:** [yes/no]
**Estimated time:** [5-15 minutes depending on engines available]
```

### Step 2: Evil Twin Challenge (unless --skip-twin)

Before building anything, challenge the approach using `/evil-twin`:

1. State your planned approach and confidence level
2. Run the full Evil Twin protocol (Step 0-3 from the evil-twin skill)
3. Capture the post-challenge confidence and any adjustments

Record the output:

```markdown
**Twin Phase Complete**
- Pre-challenge confidence: X%
- Post-challenge confidence: Y%
- Adjustments: [list what changed, or "none"]
- Twin verdict: FLAWED / PROCEED WITH CAUTION / SOUND
```

**Decision gate:**
- If Twin verdict is **FLAWED** and post-challenge confidence is below 70% → STOP the pipeline. Report the findings and let the user decide whether to continue.
- If Twin verdict is **PROCEED WITH CAUTION** → continue to brainstorm phase
- If Twin verdict is **SOUND** and confidence >= 90% → skip brainstorm, go directly to forge

### Step 3: Brainstorm/Tribunal (unless --skip-brainstorm or auto-skipped)

If brainstorm is needed (confidence 70-89% after Twin), invoke `/brainstorm`:

Provide the brainstorm with:
- The original task
- The Evil Twin's challenges and your rebuttals
- Your adjusted approach

The brainstorm will have available AIs bid on confidence. Capture:

```markdown
**Brainstorm Phase Complete**
- Winning approach: [which AI's approach or merged]
- Consensus confidence: X%
- Key insights: [what brainstorm added that Twin didn't catch]
```

If the brainstorm reveals fundamental disagreement (no consensus above 70%), invoke `/tribunal` instead for a structured debate round. Use the brainstorm outputs as evidence.

**Alternative:** If confidence is below 75% after Twin and the issue is a factual question (not a design choice), use `/tribunal` directly instead of `/brainstorm`.

### Step 4: Forge with Doppelganger

This is the core competitive build. Invoke `/forge` with the Doppelganger as one of the engines:

**Forge invocation parameters:**
- **Task:** The refined task (incorporating Twin adjustments and brainstorm insights)
- **Engines:** `doppelganger` + whatever other engines are available (codex, gemini, etc.)
- **Fitness:** Auto-detect from project (build + test + lint)

The forge dispatches each engine into its own worktree. The Doppelganger gets the task prompt BLIND — it does not see the Twin's challenges, the brainstorm output, or your adjusted approach. It solves from scratch.

This is the key value: while you refined your approach through Twin + brainstorm, the Doppelganger independently validates whether a fresh perspective reaches the same conclusion.

**What to pass to forge:**
- The ORIGINAL task description (not the refined one) — keeping Doppelganger blind
- The fitness command from detect-project.sh
- Request all available engines including doppelganger

**Forge output:** A manifest.json with scores, patches, and a winner.

### Step 5: Synthesis Report

After forge completes, produce the pipeline report:

```markdown
## Evil Pipeline Report

**Task:** [original task]
**Duration:** [total pipeline time]
**Engines competed:** [list]

### Phase Results

| Phase | Outcome | Confidence |
|-------|---------|------------|
| Evil Twin | [SOUND/CAUTION/FLAWED] | [X%] |
| Brainstorm | [consensus/split] | [X%] |
| Forge Winner | [engine name] | Score: [X/100] |

### Forge Scoreboard

| Engine | Pass | Score | Diff Lines | Duration |
|--------|------|-------|------------|----------|
| doppelganger | [y/n] | [X] | [N] | [Xs] |
| codex | [y/n] | [X] | [N] | [Xs] |
| gemini | [y/n] | [X] | [N] | [Xs] |

### Convergence Analysis

Compare the Doppelganger's blind solution against your Twin-refined approach:

| Area | Your Approach (Twin-refined) | Doppelganger (blind) | Other Engines |
|------|------------------------------|---------------------|---------------|
| [aspect] | [what you did] | [what doppelganger did] | [what others did] |

### Key Findings

- **Convergence points:** [where multiple independent approaches agreed]
- **Divergence points:** [where approaches differed — these are the real design decisions]
- **Twin-caught issues:** [things the Evil Twin found that forge confirmed or denied]
- **Surprise findings:** [things no one predicted — emerged only from competitive building]

### Recommendation

[One of:]
- **SHIP IT** — forge winner passes fitness, converges with Twin-refined approach, high confidence across pipeline
- **MERGE BEST** — take [specific parts] from [engine] and [specific parts] from [engine]. Apply the merge.
- **MANUAL REVIEW** — significant divergence or low scores. Present patches for user review.
- **ABORT** — fundamental issues found at multiple pipeline stages. Rethink the approach.

### Applied Changes

If recommendation is SHIP IT or MERGE BEST, apply the winning/merged solution:
1. Apply the winning patch from forge (or merged patches)
2. Run build + tests to verify
3. List the final files changed
```

---

## Quick Pipeline Mode

When the task is moderately complex but doesn't warrant the full 15-minute pipeline:

`/evil-pipeline --quick "task"`

1. Run `/evil-twin --quick` (inline, no subagent) — 30 seconds
2. Skip brainstorm entirely
3. Run `/forge` with doppelganger + 1 other engine — 3-5 minutes
4. Brief comparison report

Total time: ~5 minutes instead of ~15.

---

## Configuration

Uses Evil Twin's config file: `~/.evil-twin/config.json`

| Key | Default | Description |
|-----|---------|-------------|
| `pipeline_auto_skip_brainstorm` | `false` | Skip brainstorm when Twin says SOUND |
| `pipeline_forge_engines` | `""` | Override which engines to include (CSV). Empty = all available |
| `pipeline_timeout` | `600` | Total pipeline timeout in seconds |
| `pipeline_stop_on_flawed` | `true` | Stop pipeline if Twin verdict is FLAWED with <70% confidence |

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| AI Buddies not installed | Error with install instructions. Do NOT fall back to Evil Twin only. |
| No external engines available | Run forge with doppelganger only (still valuable — blind solve vs your approach) |
| Twin says FLAWED, conf < 70% | Stop pipeline (unless `pipeline_stop_on_flawed` is false). Report findings. |
| Forge times out | Report partial results. Whatever engines completed still get scored. |
| Doppelganger produces empty diff | Report "Doppelganger made no changes" — may indicate task was unclear or already solved. |
| All engines fail fitness | Report all failures. The failure modes themselves are informative. |

## Anti-patterns

- **Running evil-pipeline on trivial tasks.** Renaming a variable does not need 3 AIs and 15 minutes. Use `/evil-twin --quick` for small things.
- **Ignoring the convergence analysis.** The whole point of the pipeline is to see where independent approaches agree and disagree. If you skip the analysis, you've just wasted compute.
- **Re-running the pipeline.** One run per task. If the result is unclear, investigate manually or break the task into smaller pieces.
- **Leaking context to the Doppelganger.** The forge task prompt must be the ORIGINAL task, not your refined version. The Doppelganger's value is independence.
