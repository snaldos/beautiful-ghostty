#!/usr/bin/env bash

set -Eeuo pipefail

# Remove only files and config lines owned by the Beautiful Ghostty installer.

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
[[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]] && SCRIPT_DIR="."
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

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
PURGE=0
NO_RELOAD=0
TEMP_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./uninstall.sh [OPTIONS] [GHOSTTY_CONFIG_OR_DIRECTORY]

Options:
  --config PATH       Ghostty config file or directory
  --install-dir PATH  Installed source directory
  --bin-dir PATH      Directory containing beautiful-ghostty
  --purge              Also remove generated shader state and selections
  --no-reload          Do not signal running Ghostty processes
  -h, --help           Show this help
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

resolve_config_path() {
  local input="$1"

  if [[ -z "$input" ]]; then
    printf '%s/ghostty/config.ghostty' "${XDG_CONFIG_HOME:-$HOME/.config}"
  elif [[ -d "$(expand_home "$input")" || "$input" == */ ]]; then
    printf '%s/config.ghostty' "$(expand_home "${input%/}")"
  else
    expand_home "$input"
  fi
}

write_without_managed_block() {
  local config_file="$1"
  local line
  local skipping=0

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

    [[ "$skipping" == 1 ]] || printf '%s\n' "$line"
  done <"$config_file"

  [[ "$skipping" == 0 ]] || fail "unterminated managed block in $config_file"
}

remove_config_include() {
  local backup temporary timestamp

  [[ -f "$CONFIG_EDIT_FILE" ]] || return 0
  temporary="$(mktemp "$CONFIG_EDIT_DIR/.beautiful-ghostty-uninstall.XXXXXX")"
  TEMP_FILE="$temporary"
  write_without_managed_block "$CONFIG_EDIT_FILE" >"$temporary"
  chmod --reference="$CONFIG_EDIT_FILE" "$temporary"

  if cmp -s -- "$CONFIG_EDIT_FILE" "$temporary"; then
    rm -- "$temporary"
    TEMP_FILE=""
    return 0
  fi

  timestamp="$(date '+%Y%m%d-%H%M%S')"
  backup="$CONFIG_EDIT_FILE.bak.$timestamp"
  [[ ! -e "$backup" ]] || backup="$backup.$$"
  cp -p -- "$CONFIG_EDIT_FILE" "$backup"
  mv -- "$temporary" "$CONFIG_EDIT_FILE"
  temporary=""
  TEMP_FILE=""

  if ! ghostty +validate-config --config-file="$CONFIG_FILE"; then
    cp -p -- "$backup" "$CONFIG_EDIT_FILE"
    fail "Ghostty rejected the config; restored $backup"
  fi

  printf 'Config backup: %s\n' "$backup"
}

reload_ghostty() {
  local proc pid process_name
  local signalled=0

  [[ "$NO_RELOAD" == 0 ]] || return 0
  for proc in /proc/[0-9]*; do
    [[ -r "$proc/comm" ]] || continue
    IFS= read -r process_name <"$proc/comm" || continue
    [[ "$process_name" == ghostty ]] || continue
    pid="${proc##*/}"
    kill -USR2 "$pid" 2>/dev/null && signalled=1
  done

  [[ "$signalled" == 1 ]] || warn "uninstalled successfully, but no running Ghostty instance was reloaded"
}

cleanup() {
  [[ -z "$TEMP_FILE" ]] || rm -f -- "$TEMP_FILE"
}

remove_owned_files() {
  if [[ -e "$COMMAND_FILE" || -L "$COMMAND_FILE" ]]; then
    if [[ -f "$COMMAND_FILE" ]] && grep -Fqx "$WRAPPER_MARKER" "$COMMAND_FILE"; then
      rm -- "$COMMAND_FILE"
    else
      warn "left unmanaged command untouched: $COMMAND_FILE"
    fi
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    if [[ -f "$INSTALL_DIR/$INSTALL_MARKER" ]]; then
      rm -rf -- "$INSTALL_DIR"
    else
      warn "left unrecognized install directory untouched: $INSTALL_DIR"
    fi
  fi

  if [[ "$PURGE" == 1 ]]; then
    rm -rf -- "$RUNTIME_DIR"
  fi
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
    --purge)
      PURGE=1
      shift
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
  INSTALL_DIR="$(make_absolute "$INSTALL_DIR")"
  BIN_DIR="$(make_absolute "$BIN_DIR")"
  COMMAND_FILE="$BIN_DIR/beautiful-ghostty"
  RUNTIME_DIR="$CONFIG_DIR/beautiful-ghostty"

  command -v ghostty >/dev/null 2>&1 || fail "ghostty is required"
  trap cleanup EXIT
  remove_config_include
  reload_ghostty
  remove_owned_files

  printf '\nBeautiful Ghostty uninstalled.\n'
  [[ "$PURGE" == 1 ]] && printf 'Generated state removed: %s\n' "$RUNTIME_DIR" ||
    printf 'Generated state retained: %s (use --purge to remove it)\n' "$RUNTIME_DIR"
}

main "$@"
