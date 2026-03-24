---
name: evil-twin-config
description: Show or edit Evil Twin configuration
---

# /evil-twin-config — Configuration

## Step 1: Check for existing config

Read the config file at `~/.evil-twin/config.json`. If it doesn't exist, show the defaults.

## Step 2: Display current config

Show the user their current configuration:

```markdown
## Evil Twin Configuration

| Setting | Current | Default | Description |
|---------|---------|---------|-------------|
| `threshold` | {value} | `0.92` | Auto-trigger confidence threshold |
| `max_challenges` | {value} | `5` | Max challenges per session |
| `auto_trigger` | {value} | `true` | Enable auto-trigger |
| `escalation_threshold` | {value} | `0.85` | Escalation threshold |
| `quick_default` | {value} | `false` | Quick mode by default |
| `easter_eggs` | {value} | `false` | Themed messages |
| `doppelganger_timeout` | {value} | `300` | Doppelganger timeout (seconds) |
| `doppelganger_run_tests` | {value} | `true` | Run tests in Doppelganger |
| `doppelganger_run_build` | {value} | `true` | Run build in Doppelganger |

Config file: `~/.evil-twin/config.json`
```

## Step 3: If user wants to change a value

Write the updated config to `~/.evil-twin/config.json`. Create the directory if needed.

Example config:
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
