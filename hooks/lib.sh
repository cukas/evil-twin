#!/usr/bin/env bash
# Evil Twin — shared helpers

EVIL_TWIN_CONFIG_DIR="$HOME/.evil-twin"

evil_twin_require_jq() {
  command -v jq &>/dev/null || { echo "Evil Twin requires jq. Install: brew install jq" >&2; exit 1; }
}

evil_twin_config() {
  local key="$1"
  local default="$2"
  local config_file="$EVIL_TWIN_CONFIG_DIR/config.json"
  [ ! -f "$config_file" ] && echo "$default" && return
  evil_twin_require_jq
  local value
  value=$(jq -r --arg k "$key" '.[$k] // empty' "$config_file" 2>/dev/null)
  [ -z "$value" ] && echo "$default" || echo "$value"
}

evil_twin_debug() {
  local msg="$1"
  local debug
  debug=$(evil_twin_config "debug" "false")
  [ "$debug" = "true" ] && echo "[evil-twin] $msg" >> "$EVIL_TWIN_CONFIG_DIR/debug.log"
}
