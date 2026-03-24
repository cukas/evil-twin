---
name: doppelganger
description: Independent verification — a second Claude solves the same problem blind in a worktree, then both approaches are compared
---

# /doppelganger — Independent Blind Verification

A second Claude independently solves the same problem WITHOUT seeing your solution. Then you compare. Convergence = high confidence. Divergence = the real design decision.

## When to use this

- **High-risk changes:** core workflows, security, state management, database migrations
- **Architecture decisions:** when multiple valid approaches exist and you want to verify yours isn't just "obvious to me"
- **Manual only:** user invokes `/doppelganger` or `/doppelganger "problem description"`

## What makes this different

| | Evil Twin | Doppelganger | Tribunal |
|---|---|---|---|
| Sees your solution? | Yes (attacks it) | No (solves blind) | Yes (debates it) |
| Produces code? | No (reasoning only) | Yes (full implementation) | No (arguments only) |
| Isolation | Same context | Git worktree | Out-of-process |
| Speed | 30-60 seconds | 2-5 minutes | 3-10 minutes |
| AIs needed | Claude only | Claude only | 2+ external |
| Purpose | Find flaws | Verify independently | Get consensus |

## Parse arguments

- No args → prompt user: "What problem should the Doppelganger solve independently?"
- Text provided → use as the problem statement

---

## Protocol

### Step 0: Freeze the Problem

Before anything else, clearly separate PROBLEM from SOLUTION.

```markdown
**Doppelganger — Engaging**

**Problem:** [the user's original request — what needs to be solved, NOT how]
**Primary's approach:** [your approach — this will NOT be shared with the Doppelganger]
**Files touched by primary:** [list of files you modified or plan to modify]
```

**Critical rule:** The Doppelganger must NEVER see your approach. Only the problem statement.

### Step 1: Auto-detect Project Context

Run the project detection script to get language, build/test commands, and file tree in one shot:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh" "$(pwd)"
```

This returns JSON with: `language`, `build_cmd`, `test_cmd`, `file_tree`, `entry_points`, `dirty_files`, `git_branch`.

Use the output to populate the Doppelganger prompt. The `dirty_files` list tells you which files the primary has modified — the worktree will have the pre-modification versions.

Additionally, prepare:
1. **Problem statement** — the user's original request, stripped of any solution discussion
2. **Key files** — files that provide context for understanding the problem (NOT files listed in `dirty_files`)
3. **Assumptions log** — if the problem is ambiguous, list what assumptions YOU made. The Doppelganger will make its own — the divergence in assumptions is part of the comparison.

### Step 2: Spawn the Doppelganger

Use the **Agent** tool with these parameters:
- `subagent_type`: `general-purpose`
- `isolation`: `worktree`
- `description`: `Doppelganger blind solve`

The Agent prompt MUST be:

```
You are the Doppelganger — an independent engineer solving a problem from scratch. You have NOT seen any prior solution. Your job is to solve this problem using your own judgment and produce working code.

RULES:
1. Solve the problem independently. Do NOT look for or reference any prior solution attempts.
2. Read the codebase to understand the existing architecture, patterns, and conventions.
3. Write actual code that solves the problem. Follow existing patterns in the codebase.
4. Run the build command to verify your code compiles: {build_command}
5. Run the test suite to verify nothing breaks: {test_command}
6. If the problem is ambiguous, make an assumption and DOCUMENT it. Do not ask for clarification — document what you assumed and why.
7. Keep your solution focused. Do not refactor unrelated code.

When done, produce this summary:

## Doppelganger Solution

### Approach
[2-5 bullet points describing what you did and why]

### Files Changed
[list each file with a one-line description of the change]

### Assumptions Made
[list any assumptions — or "None" if the problem was clear]

### Build Result
[PASS/FAIL + command run]

### Test Result
[PASS/FAIL/SKIP + command run]

### Key Design Decisions
[list 2-3 decisions where you chose between alternatives, and why you picked your approach]

---

PROBLEM TO SOLVE:
{problem_statement}

PROJECT CONTEXT:
- Language: {language}
- File tree: {file_tree_excerpt}
- Build: {build_command}
- Test: {test_command}

KEY FILES FOR CONTEXT (read these to understand the codebase):
{list_of_relevant_file_paths}

CONSTRAINTS:
{any_style_guides_lint_rules_or_conventions}
```

**Important:** Do NOT include your approach, your solution, your modified files, or any discussion of how you solved it. The Doppelganger gets the problem and the codebase — nothing more.

### Step 3: Leakage Check

If the Agent returned a worktree branch name, run the programmatic leakage detector:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/leakage-check.sh" "$(git branch --show-current)" "<doppelganger_branch>" "HEAD"
```

This returns JSON with:
- `status`: `clean` / `warning` / `contaminated`
- `file_overlap`: how many files both modified
- `identical_hunks`: non-trivial identical code lines
- `warnings`: specific leakage signals (suspicious file overlap, identical code, name collisions)

**Interpret the result:**
- `clean` → proceed to comparison with full confidence
- `warning` → note the warnings in the report but proceed
- `contaminated` → flag prominently:

```markdown
**Leakage Warning:** Doppelganger may have been contaminated. [warnings from script]. Results should be treated as review, not independent verification.
```

If the Agent did NOT return a branch (e.g., worktree was auto-cleaned), fall back to manual check:
1. Did the Doppelganger reference variable/function names that ONLY exist in your solution?
2. Did it modify the exact same non-obvious lines you did?

### Step 4: Comparison

Produce the structured comparison report:

```markdown
## Doppelganger Report

**Problem:** [one-line summary]
**Primary files changed:** [list]
**Doppelganger files changed:** [list]
**Leakage check:** CLEAN / WARNING

### Convergence (both approaches agreed)

| Area | Primary | Doppelganger | Confidence |
|------|---------|--------------|------------|
| [e.g., auth middleware] | [what you did] | [what they did] | HIGH — independent convergence |

### Divergence (different approaches)

| Area | Primary | Doppelganger | Analysis |
|------|---------|--------------|----------|
| [e.g., caching strategy] | [your approach] | [their approach] | [why they differ, which is better, or trade-off] |

### Primary-only (Doppelganger missed)
- [things you addressed that the Doppelganger didn't — may indicate over-engineering OR thoroughness]

### Doppelganger-only (you missed)
- [things the Doppelganger addressed that you didn't — missed opportunities or unnecessary additions]

### Assumption Divergence
| Topic | Primary assumed | Doppelganger assumed | Impact |
|-------|----------------|---------------------|--------|
| [e.g., auth method] | [JWT] | [session cookies] | [significant — affects architecture] |

### Verdict

**Convergence score:** X/10 (10 = identical approaches, 0 = completely different)

[One of:]
- **HIGH CONVERGENCE (7-10):** Independent verification successful. High confidence in the approach.
- **MODERATE CONVERGENCE (4-6):** Key decisions diverged. Review the divergence points before proceeding.
- **LOW CONVERGENCE (0-3):** Fundamentally different approaches. Escalate to `/tribunal` or discuss with user.

### Recommended Action
[What to do — merge primary as-is, adopt Doppelganger's approach for X, cherry-pick specific decisions, or escalate]
```

### Step 5: Worktree Cleanup

If the Agent tool returned a worktree path and branch:

- If verdict is HIGH CONVERGENCE → the worktree can be cleaned up (the Agent tool handles this automatically if no changes are kept)
- If there are useful Doppelganger changes to cherry-pick → inform the user of the worktree branch name so they can `git cherry-pick` or `git diff` manually
- State the worktree branch name in the report for reference

---

## Quick Comparison Mode

When invoked with `--quick`, skip the worktree and code generation. Instead:

1. State the problem
2. Spawn an Agent (no worktree) that produces only an APPROACH (no code):
   - "Here's how I'd solve this" in 5-7 bullet points
   - Key design decisions
   - Files I'd change
3. Compare approaches at the plan level
4. Report convergence/divergence

This is faster (~30-60 seconds) but less rigorous — you're comparing plans, not verified code.

---

## Configuration

Uses the same config file as Evil Twin: `~/.evil-twin/config.json`

Additional Doppelganger-specific keys:

| Key | Default | Description |
|-----|---------|-------------|
| `doppelganger_timeout` | `300` | Timeout in seconds for Doppelganger solve |
| `doppelganger_run_tests` | `true` | Whether Doppelganger should run tests |
| `doppelganger_run_build` | `true` | Whether Doppelganger should run build |

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Problem too vague | Doppelganger documents assumptions. High assumption divergence = signal to clarify requirements. |
| Trivial problem (one obvious solution) | Both converge trivially. Report: "Redundant — single obvious path. Confidence was already high." |
| Doppelganger can't build | Return partial results + build error. May reveal environment issue or genuinely harder problem. |
| Timeout | Return partial with "Incomplete — timeout at step X." Partial results still useful for plan-level comparison. |
| No tests in project | Skip test step, report SKIP. Compare code and approach only. |

## Anti-patterns

- **Leaking the solution.** The ENTIRE value is independence. If you include your approach in the prompt, you've turned Doppelganger into a rubber stamp. Triple-check the prompt.
- **Comparing line-by-line.** Two valid solutions can look completely different at the line level. Compare SEMANTICALLY — what decisions were made, not what syntax was used.
- **Running Doppelganger on trivial tasks.** It takes 2-5 minutes and uses a worktree. Don't use it for renaming a variable. Evil Twin `--quick` is for that.
- **Ignoring Doppelganger-only findings.** If the Doppelganger addressed something you didn't, that's not "extra" — it might be something you missed.
- **Re-running on the same problem.** One Doppelganger per problem. If you need more perspectives, escalate to `/tribunal` or `/forge`.
