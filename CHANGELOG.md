# Changelog

## 1.0.0 (2026-03-24)

### Added
- `/evil-twin` skill — adversarial self-challenge with Agent subagent
  - Full mode: 5 challenges via 3 frameworks (inversion, pre-mortem, second-order)
  - Quick mode (`--quick`): inline 3-challenge sanity check
  - Targeted mode (`"concern"`): focused challenge on specific area
  - 3-step protocol: Capture → Twin Attack → Rebuttal → Resolution
  - Anti-convergence prompt design
- `/doppelganger` skill — independent blind verification
  - Full mode: git worktree isolation, writes code, runs build + tests
  - Quick mode (`--quick`): plan-level comparison without worktree
  - Leakage detection to verify independence
  - Structured comparison: convergence, divergence, missed opportunities
  - Convergence scoring (0-10) with escalation recommendations
- `/evil-twin-help` command reference
- `/evil-twin-config` configuration management
- Configurable thresholds, timeouts, and easter eggs
