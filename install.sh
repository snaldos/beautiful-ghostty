#!/usr/bin/env bash

set -Eeuo pipefail

# Install immutable Beautiful Ghostty sources outside the clone, expose one
# user command, and add one managed include to the selected Ghostty config.

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
[[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]] && SCRIPT_DIR="."
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

SOURCE_MANAGER="$SCRIPT_DIR/ghostty-shaders.sh"
SOURCE_SHADERS="$SCRIPT_DIR/shaders"
SOURCE_VERSION="$SCRIPT_DIR/VERSION"

BEGIN_MARKER="# BEGIN beautiful-ghostty"
END_MARKER="# END beautiful-ghostty"
WRAPPER_MARKER="# Managed by the Beautiful Ghostty installer."
INSTALL_MARKER=".installed-by-beautiful-ghostty"

CONFIG_INPUT=""
CONFIG_FILE=""
CONFIG_DIR=""
CONFIG_EDIT_FILE=""
CONFIG_EDIT_DIR=""
INSTALL_DIR="${BEAUTIFUL_GHOSTTY_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/beautiful-ghostty}"
BIN_DIR="${BEAUTIFUL_GHOSTTY_BIN_DIR:-$HOME/.local/bin}"
COMMAND_FILE=""
RUNTIME_DIR=""
ACTIVE_CONFIG=""
NO_RELOAD=0

TEMP_INSTALL=""
PREVIOUS_INSTALL=""
TEMP_WRAPPER=""
PREVIOUS_WRAPPER=""
TEMP_CONFIG=""
CONFIG_BACKUP=""
RUNTIME_BACKUP=""
HAD_CONFIG=0
HAD_RUNTIME=0
INSTALL_REPLACED=0
WRAPPER_REPLACED=0
CONFIG_REPLACED=0
SUCCESS=0

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [OPTIONS] [GHOSTTY_CONFIG_OR_DIRECTORY]

Options:
  --config PATH       Ghostty config file or directory
  --install-dir PATH  Installed source directory
  --bin-dir PATH      Directory for the beautiful-ghostty command
  --no-reload         Do not signal running Ghostty processes
  -h, --help          Show this help

Defaults:
  config:      ${XDG_CONFIG_HOME:-~/.config}/ghostty/config.ghostty
  install dir: ${XDG_DATA_HOME:-~/.local/share}/beautiful-ghostty
  command:     ~/.local/bin/beautiful-ghostty
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

expand_home() {
  printf '%s' "${1/#\~/$HOME}"
}

make_absolute() {
  local value
  value="$(expand_home "$1")"
  case "$value" in
  /*) printf '%s' "$value" ;;
  *) printf '%s/%s' "$PWD" "$value" ;;
  esac
}

reject_newline() {
  [[ "$1" != *$'\n'* ]] || fail "paths containing newlines are unsupported"
}

resolve_config_path() {
  local input="$1"
  local default_dir

  if [[ -z "$input" ]]; then
    default_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
    printf '%s/config.ghostty' "$default_dir"
    return
  fi

  input="$(expand_home "$input")"
  if [[ -d "$input" || "$input" == */ ]]; then
    printf '%s/config.ghostty' "${input%/}"
  else
    printf '%s' "$input"
  fi
}

quote_ghostty_path() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

write_updated_config() {
  local config_file="$1"
  local line
  local skipping=0
  local -a retained=()

  if [[ -f "$config_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$BEGIN_MARKER" ]]; then
        [[ "$skipping" == 0 ]] || fail "nested managed block in $config_file"
        skipping=1
        continue
      fi

      if [[ "$line" == "$END_MARKER" ]]; then
        [[ "$skipping" == 1 ]] || fail "managed end marker without a begin marker in $config_file"
        skipping=0
        continue
      fi

      [[ "$skipping" == 1 ]] || retained+=("$line")
    done <"$config_file"
  fi

  [[ "$skipping" == 0 ]] || fail "unterminated managed block in $config_file"

  while ((${#retained[@]} > 0)); do
    local last_index=$((${#retained[@]} - 1))
    [[ -z "${retained[$last_index]}" ]] || break
    unset 'retained[$last_index]'
  done

  ((${#retained[@]} == 0)) || printf '%s\n' "${retained[@]}"
  printf '\n%s\n' "$BEGIN_MARKER"
  printf '# Generated shader state; rerun install.sh to update this path.\n'
  printf 'config-file = ?%s\n' "$(quote_ghostty_path "$ACTIVE_CONFIG")"
  printf '%s\n' "$END_MARKER"
}

write_command_wrapper() {
  local target="$1"

  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$WRAPPER_MARKER"
    printf 'export GHOSTTY_CONFIG=%q\n' "$CONFIG_FILE"
    printf 'exec %q "$@"\n' "$INSTALL_DIR/ghostty-shaders.sh"
  } >"$target"
  chmod 0755 "$target"
}

backup_runtime() {
  local parent

  [[ -d "$RUNTIME_DIR" ]] || return 0
  parent="${RUNTIME_DIR%/*}"
  RUNTIME_BACKUP="$(mktemp -d "$parent/.beautiful-ghostty-runtime-backup.XXXXXX")"
  cp -a -- "$RUNTIME_DIR/." "$RUNTIME_BACKUP/"
  HAD_RUNTIME=1
}

install_sources() {
  local parent

  parent="${INSTALL_DIR%/*}"
  mkdir -p -- "$parent"
  TEMP_INSTALL="$(mktemp -d "$parent/.beautiful-ghostty-install.XXXXXX")"

  cp -- "$SOURCE_MANAGER" "$TEMP_INSTALL/ghostty-shaders.sh"
  chmod 0755 "$TEMP_INSTALL/ghostty-shaders.sh"
  mkdir -- "$TEMP_INSTALL/shaders"
  cp -a -- "$SOURCE_SHADERS/background" "$TEMP_INSTALL/shaders/background"
  cp -a -- "$SOURCE_SHADERS/combined" "$TEMP_INSTALL/shaders/combined"
  cp -a -- "$SOURCE_SHADERS/cursor" "$TEMP_INSTALL/shaders/cursor"
  cp -- "$SOURCE_VERSION" "$TEMP_INSTALL/VERSION"
  cp -- "$SCRIPT_DIR/LICENSE" "$TEMP_INSTALL/LICENSE"
  cp -- "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" "$TEMP_INSTALL/THIRD_PARTY_NOTICES.md"
  cp -a -- "$SCRIPT_DIR/LICENSES" "$TEMP_INSTALL/LICENSES"
  printf 'Beautiful Ghostty managed installation\n' >"$TEMP_INSTALL/$INSTALL_MARKER"

  if [[ -e "$INSTALL_DIR" ]]; then
    [[ -f "$INSTALL_DIR/$INSTALL_MARKER" ]] ||
      fail "refusing to replace unrecognized directory: $INSTALL_DIR"
    PREVIOUS_INSTALL="$parent/.beautiful-ghostty-previous.$$"
    [[ ! -e "$PREVIOUS_INSTALL" ]] || fail "temporary rollback path already exists: $PREVIOUS_INSTALL"
    mv -- "$INSTALL_DIR" "$PREVIOUS_INSTALL"
    INSTALL_REPLACED=1
  fi

  mv -- "$TEMP_INSTALL" "$INSTALL_DIR"
  TEMP_INSTALL=""
  INSTALL_REPLACED=1
}

install_wrapper() {
  mkdir -p -- "$BIN_DIR"
  COMMAND_FILE="$BIN_DIR/beautiful-ghostty"
  TEMP_WRAPPER="$(mktemp "$BIN_DIR/.beautiful-ghostty-command.XXXXXX")"
  write_command_wrapper "$TEMP_WRAPPER"

  if [[ -e "$COMMAND_FILE" || -L "$COMMAND_FILE" ]]; then
    if [[ -f "$COMMAND_FILE" ]] && grep -Fqx "$WRAPPER_MARKER" "$COMMAND_FILE"; then
      PREVIOUS_WRAPPER="$BIN_DIR/.beautiful-ghostty-command-previous.$$"
      mv -- "$COMMAND_FILE" "$PREVIOUS_WRAPPER"
      WRAPPER_REPLACED=1
    else
      fail "refusing to replace unmanaged command: $COMMAND_FILE"
    fi
  fi

  mv -- "$TEMP_WRAPPER" "$COMMAND_FILE"
  TEMP_WRAPPER=""
  WRAPPER_REPLACED=1
}

install_config_include() {
  local timestamp

  mkdir -p -- "$CONFIG_EDIT_DIR"
  [[ -f "$CONFIG_EDIT_FILE" ]] && HAD_CONFIG=1

  TEMP_CONFIG="$(mktemp "$CONFIG_EDIT_DIR/.beautiful-ghostty-config.XXXXXX")"
  write_updated_config "$CONFIG_EDIT_FILE" >"$TEMP_CONFIG"
  if [[ -f "$CONFIG_EDIT_FILE" ]]; then
    chmod --reference="$CONFIG_EDIT_FILE" "$TEMP_CONFIG"
  else
    chmod 0644 "$TEMP_CONFIG"
  fi

  if [[ -f "$CONFIG_EDIT_FILE" ]] && cmp -s -- "$CONFIG_EDIT_FILE" "$TEMP_CONFIG"; then
    rm -- "$TEMP_CONFIG"
    TEMP_CONFIG=""
    return
  fi

  if [[ -f "$CONFIG_EDIT_FILE" ]]; then
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    CONFIG_BACKUP="$CONFIG_EDIT_FILE.bak.$timestamp"
    [[ ! -e "$CONFIG_BACKUP" ]] || CONFIG_BACKUP="$CONFIG_BACKUP.$$"
    cp -p -- "$CONFIG_EDIT_FILE" "$CONFIG_BACKUP"
  fi

  mv -- "$TEMP_CONFIG" "$CONFIG_EDIT_FILE"
  TEMP_CONFIG=""
  CONFIG_REPLACED=1
}

generate_active_state() {
  local manager="$INSTALL_DIR/ghostty-shaders.sh"
  local state="$RUNTIME_DIR/state"

  if [[ -f "$state" ]]; then
    GHOSTTY_CONFIG="$CONFIG_FILE" "$manager" --no-reload apply >/dev/null
  else
    GHOSTTY_CONFIG="$CONFIG_FILE" "$manager" --no-reload set-profile quality >/dev/null
    GHOSTTY_CONFIG="$CONFIG_FILE" "$manager" --no-reload set combined cosmos >/dev/null
  fi

  GHOSTTY_CONFIG="$CONFIG_FILE" "$manager" validate
}

reload_ghostty() {
  [[ "$NO_RELOAD" == 0 ]] || return 0

  if ! GHOSTTY_CONFIG="$CONFIG_FILE" "$INSTALL_DIR/ghostty-shaders.sh" reload >/dev/null 2>&1; then
    warn "installed successfully, but no running Ghostty instance was reloaded"
  fi
}

cleanup() {
  local status=$?

  trap - EXIT
  [[ -z "$TEMP_INSTALL" ]] || rm -rf -- "$TEMP_INSTALL"
  [[ -z "$TEMP_WRAPPER" ]] || rm -f -- "$TEMP_WRAPPER"
  [[ -z "$TEMP_CONFIG" ]] || rm -f -- "$TEMP_CONFIG"

  if [[ "$status" -ne 0 || "$SUCCESS" != 1 ]]; then
    if [[ "$CONFIG_REPLACED" == 1 ]]; then
      if [[ "$HAD_CONFIG" == 1 && -n "$CONFIG_BACKUP" ]]; then
        cp -p -- "$CONFIG_BACKUP" "$CONFIG_EDIT_FILE"
      else
        rm -f -- "$CONFIG_EDIT_FILE"
      fi
    fi

    if [[ "$WRAPPER_REPLACED" == 1 ]]; then
      rm -f -- "$COMMAND_FILE"
      [[ -z "$PREVIOUS_WRAPPER" ]] || mv -- "$PREVIOUS_WRAPPER" "$COMMAND_FILE"
    fi

    if [[ "$INSTALL_REPLACED" == 1 ]]; then
      rm -rf -- "$INSTALL_DIR"
      [[ -z "$PREVIOUS_INSTALL" ]] || mv -- "$PREVIOUS_INSTALL" "$INSTALL_DIR"
    fi

    if [[ "$HAD_RUNTIME" == 1 ]]; then
      rm -rf -- "$RUNTIME_DIR"
      mv -- "$RUNTIME_BACKUP" "$RUNTIME_DIR"
      RUNTIME_BACKUP=""
    else
      rm -rf -- "$RUNTIME_DIR"
      [[ -z "$RUNTIME_BACKUP" ]] || rm -rf -- "$RUNTIME_BACKUP"
      RUNTIME_BACKUP=""
    fi
  else
    [[ -z "$PREVIOUS_INSTALL" ]] || rm -rf -- "$PREVIOUS_INSTALL"
    [[ -z "$PREVIOUS_WRAPPER" ]] || rm -f -- "$PREVIOUS_WRAPPER"
    [[ -z "$RUNTIME_BACKUP" ]] || rm -rf -- "$RUNTIME_BACKUP"
  fi

  exit "$status"
}

main() {
  while (($# > 0)); do
    case "$1" in
    --config)
      (($# >= 2)) || fail "--config requires a path"
      [[ -z "$CONFIG_INPUT" ]] || fail "only one config path may be supplied"
      CONFIG_INPUT="$2"
      shift 2
      ;;
    --install-dir)
      (($# >= 2)) || fail "--install-dir requires a path"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --bin-dir)
      (($# >= 2)) || fail "--bin-dir requires a path"
      BIN_DIR="$2"
      shift 2
      ;;
    --no-reload)
      NO_RELOAD=1
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) fail "unknown option: $1" ;;
    *)
      [[ -z "$CONFIG_INPUT" ]] || fail "only one config path may be supplied"
      CONFIG_INPUT="$1"
      shift
      ;;
    esac
  done
  (($# == 0)) || fail "unexpected argument: $1"

  INSTALL_DIR="$(make_absolute "$INSTALL_DIR")"
  BIN_DIR="$(make_absolute "$BIN_DIR")"
  CONFIG_FILE="$(make_absolute "$(resolve_config_path "$CONFIG_INPUT")")"
  CONFIG_DIR="${CONFIG_FILE%/*}"
  [[ "$CONFIG_DIR" != "$CONFIG_FILE" ]] || CONFIG_DIR="."
  if [[ -L "$CONFIG_FILE" ]]; then
    CONFIG_EDIT_FILE="$(readlink -f -- "$CONFIG_FILE")"
    [[ -n "$CONFIG_EDIT_FILE" ]] || fail "cannot resolve config symlink: $CONFIG_FILE"
  else
    CONFIG_EDIT_FILE="$CONFIG_FILE"
  fi
  CONFIG_EDIT_DIR="${CONFIG_EDIT_FILE%/*}"
  [[ "$CONFIG_EDIT_DIR" != "$CONFIG_EDIT_FILE" ]] || CONFIG_EDIT_DIR="."
  RUNTIME_DIR="$CONFIG_DIR/beautiful-ghostty"
  ACTIVE_CONFIG="$RUNTIME_DIR/active.ghostty"

  reject_newline "$INSTALL_DIR"
  reject_newline "$BIN_DIR"
  reject_newline "$CONFIG_FILE"
  reject_newline "$CONFIG_EDIT_FILE"

  [[ -x "$SOURCE_MANAGER" ]] || fail "missing executable manager: $SOURCE_MANAGER"
  [[ -d "$SOURCE_SHADERS/background" ]] || fail "missing background shaders"
  [[ -d "$SOURCE_SHADERS/cursor" ]] || fail "missing cursor shaders"
  [[ -d "$SOURCE_SHADERS/combined" ]] || fail "missing combined shaders"
  [[ -f "$SOURCE_VERSION" ]] || fail "missing VERSION"
  command -v ghostty >/dev/null 2>&1 || fail "ghostty is required"
  command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

  mkdir -p -- "$CONFIG_DIR"
  trap cleanup EXIT
  backup_runtime

  install_sources
  install_wrapper
  install_config_include
  generate_active_state

  SUCCESS=1
  reload_ghostty

  printf '\nBeautiful Ghostty installed.\n'
  printf 'Command: %s\n' "$COMMAND_FILE"
  printf 'Sources: %s\n' "$INSTALL_DIR/shaders"
  printf 'Config:  %s\n' "$CONFIG_FILE"
  printf 'Active:  %s\n' "$ACTIVE_CONFIG"
  [[ -z "$CONFIG_BACKUP" ]] || printf 'Backup:  %s\n' "$CONFIG_BACKUP"
  GHOSTTY_CONFIG="$CONFIG_FILE" "$INSTALL_DIR/ghostty-shaders.sh" status
}

main "$@"
