#!/usr/bin/env bash

set -Eeuo pipefail

# Install Beautiful Ghostty into an existing Ghostty configuration.
#
# The repository may live anywhere. The selected Ghostty config receives one
# optional absolute include for this repository's dedicated shaders.ghostty.

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
[[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]] && SCRIPT_DIR="."
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

MANAGER="$SCRIPT_DIR/ghostty-shaders.sh"
SHADER_CONFIG="$SCRIPT_DIR/shaders.ghostty"

BEGIN_MARKER="# BEGIN beautiful-ghostty"
END_MARKER="# END beautiful-ghostty"

CONFIG_INPUT=""
CONFIG_FILE=""
BACKUP_FILE=""
TEMPORARY_FILE=""
HAD_CONFIG=0
CONFIG_REPLACED=0

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [GHOSTTY_CONFIG_OR_DIRECTORY]
  ./install.sh --config GHOSTTY_CONFIG_OR_DIRECTORY

Examples:
  ./install.sh
  ./install.sh ~/.config/ghostty
  ./install.sh ~/.config/ghostty/config.ghostty
  ./install.sh --config /path/to/config.ghostty
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

resolve_config_path() {
  local input="${1:-}"
  local config_dir

  if [[ -n "$input" ]]; then
    input="${input/#\~/$HOME}"

    if [[ -d "$input" || "$input" == */ ]]; then
      config_dir="${input%/}"

      if [[ -f "$config_dir/config.ghostty" ]]; then
        printf '%s' "$config_dir/config.ghostty"
      elif [[ -f "$config_dir/config" ]]; then
        printf '%s' "$config_dir/config"
      else
        printf '%s' "$config_dir/config.ghostty"
      fi

      return
    fi

    printf '%s' "$input"
    return
  fi

  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"

  if [[ -f "$config_dir/config.ghostty" ]]; then
    printf '%s' "$config_dir/config.ghostty"
  elif [[ -f "$config_dir/config" ]]; then
    printf '%s' "$config_dir/config"
  else
    printf '%s' "$config_dir/config.ghostty"
  fi
}

quote_ghostty_path() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"

  printf '"%s"' "$value"
}

is_active_shader_setting() {
  local line="$1"

  [[ "$line" =~ ^[[:space:]]*custom-shader[[:space:]]*= ]] ||
    [[ "$line" =~ ^[[:space:]]*custom-shader-animation[[:space:]]*= ]]
}

write_updated_config() {
  local config_file="$1"
  local line
  local skipping_managed_block=0
  local -a retained_lines=()

  if [[ -f "$config_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$BEGIN_MARKER" ]]; then
        [[ "$skipping_managed_block" == "0" ]] ||
          fail "nested '$BEGIN_MARKER' block in $config_file"

        skipping_managed_block=1
        continue
      fi

      if [[ "$line" == "$END_MARKER" ]]; then
        [[ "$skipping_managed_block" == "1" ]] ||
          fail "found '$END_MARKER' without a matching begin marker"

        skipping_managed_block=0
        continue
      fi

      [[ "$skipping_managed_block" == "1" ]] && continue

      # Remove shader settings left by a manual or pre-include installation.
      # Commented examples and unrelated config-file includes remain untouched.
      if is_active_shader_setting "$line"; then
        continue
      fi

      retained_lines+=("$line")
    done <"$config_file"
  fi

  [[ "$skipping_managed_block" == "0" ]] ||
    fail "unterminated '$BEGIN_MARKER' block in $config_file"

  while [[ ${#retained_lines[@]} -gt 0 ]]; do
    local last_index
    last_index=$((${#retained_lines[@]} - 1))

    [[ -z "${retained_lines[$last_index]}" ]] || break
    unset 'retained_lines[$last_index]'
  done

  if [[ ${#retained_lines[@]} -gt 0 ]]; then
    printf '%s\n' "${retained_lines[@]}"
  fi

  printf '\n%s\n' "$BEGIN_MARKER"
  printf '# Managed by Beautiful Ghostty. Rerun install.sh after moving the repository.\n'
  printf 'config-file = ?%s\n' "$(quote_ghostty_path "$SHADER_CONFIG")"
  printf '%s\n' "$END_MARKER"
}

cleanup() {
  local status=$?

  trap - EXIT
  rm -f -- "${TEMPORARY_FILE:-}"

  if [[ "$status" -ne 0 && "$CONFIG_REPLACED" == "1" ]]; then
    if [[ "$HAD_CONFIG" == "1" && -n "$BACKUP_FILE" ]]; then
      cp -p -- "$BACKUP_FILE" "$CONFIG_FILE"
      printf 'Restored the original config from: %s\n' "$BACKUP_FILE" >&2
    else
      rm -f -- "$CONFIG_FILE"
    fi
  fi

  exit "$status"
}

main() {
  local config_dir
  local timestamp

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --config)
      [[ $# -ge 2 ]] || fail "--config requires a path"
      [[ -z "$CONFIG_INPUT" ]] || fail "only one config path may be supplied"
      CONFIG_INPUT="$2"
      shift 2
      ;;

    --help | -h)
      usage
      exit 0
      ;;

    --)
      shift
      break
      ;;

    -*)
      fail "unknown option: $1"
      ;;

    *)
      [[ -z "$CONFIG_INPUT" ]] || fail "only one config path may be supplied"
      CONFIG_INPUT="$1"
      shift
      ;;
    esac
  done

  [[ $# -eq 0 ]] || fail "unexpected argument: $1"
  [[ -x "$MANAGER" ]] ||
    fail "shader manager is not executable: $MANAGER"
  [[ -f "$SHADER_CONFIG" ]] ||
    fail "shader config not found: $SHADER_CONFIG"
  command -v ghostty >/dev/null 2>&1 ||
    fail "ghostty executable not found"

  CONFIG_FILE="$(resolve_config_path "$CONFIG_INPUT")"
  config_dir="${CONFIG_FILE%/*}"
  [[ "$config_dir" != "$CONFIG_FILE" ]] || config_dir="."

  mkdir -p -- "$config_dir"

  if [[ -f "$CONFIG_FILE" ]]; then
    HAD_CONFIG=1
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    BACKUP_FILE="$CONFIG_FILE.bak.$timestamp"
    cp -p -- "$CONFIG_FILE" "$BACKUP_FILE"
  else
    : >"$CONFIG_FILE"
  fi

  TEMPORARY_FILE="$(mktemp "$config_dir/.beautiful-ghostty-config.XXXXXX")"
  trap cleanup EXIT

  if [[ "$HAD_CONFIG" == "1" ]]; then
    cp -p -- "$CONFIG_FILE" "$TEMPORARY_FILE"
  else
    chmod 0644 "$TEMPORARY_FILE"
  fi

  write_updated_config "$CONFIG_FILE" >"$TEMPORARY_FILE"
  mv -f -- "$TEMPORARY_FILE" "$CONFIG_FILE"
  TEMPORARY_FILE=""
  CONFIG_REPLACED=1

  GHOSTTY_CONFIG="$CONFIG_FILE" \
    "$MANAGER" --no-reload set-profile quality >/dev/null

  GHOSTTY_CONFIG="$CONFIG_FILE" \
    "$MANAGER" --no-reload set combined cosmos >/dev/null

  GHOSTTY_CONFIG="$CONFIG_FILE" \
    "$MANAGER" validate

  CONFIG_REPLACED=0

  if ! GHOSTTY_CONFIG="$CONFIG_FILE" \
    "$MANAGER" reload >/dev/null 2>&1; then
    printf 'Warning: installed successfully, but no running Ghostty instance was reloaded.\n' >&2
  fi

  printf '\nBeautiful Ghostty installed.\n'
  printf 'Config:  %s\n' "$CONFIG_FILE"
  printf 'Include: %s\n' "$SHADER_CONFIG"
  printf 'Shaders: %s/shaders\n' "$SCRIPT_DIR"

  if [[ -n "$BACKUP_FILE" ]]; then
    printf 'Backup:  %s\n' "$BACKUP_FILE"
  fi

  printf 'Mode:    Combined shader / cosmos\n'
  printf 'Profile: quality\n'
}

main "$@"
