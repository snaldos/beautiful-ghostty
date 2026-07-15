#!/usr/bin/env bash

set -Eeuo pipefail

# =============================================================================
# Beautiful Ghostty shader manager
# =============================================================================
#
# The repository and installed data contain only durable shader sources. Active
# state is generated under the selected Ghostty configuration directory:
#
#   beautiful-ghostty/
#   ├── active.ghostty
#   ├── generated/*.glsl
#   └── state
#
# Generated shaders use content-addressed filenames. A real shader or GPU-profile
# change therefore changes Ghostty's configured path and forces recompilation.
# The manager is UI-independent and has no Fuzzel, Rofi, or Hyprland dependency.
#
# Commands:
#
#   beautiful-ghostty list cursor|background|combined|profiles
#   beautiful-ghostty current cursor|background|combined
#   beautiful-ghostty mode
#   beautiful-ghostty profile
#   beautiful-ghostty status
#   beautiful-ghostty set cursor|background|combined NAME|none
#   beautiful-ghostty set-profile eco|balanced|quality|ultra
#   beautiful-ghostty apply
#   beautiful-ghostty reload
#   beautiful-ghostty validate
#   beautiful-ghostty --version
#
# Global option:
#
#   --no-reload   Update generated state without signalling Ghostty.
#
# Environment override:
#
#   GHOSTTY_CONFIG   Exact Ghostty config used for runtime state and validation.
#
# =============================================================================

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
[[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]] && SCRIPT_DIR="."
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

SHADERS_DIR="$SCRIPT_DIR/shaders"
VERSION_FILE="$SCRIPT_DIR/VERSION"
GHOSTTY_CONFIG="${GHOSTTY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.ghostty}"
GHOSTTY_CONFIG="${GHOSTTY_CONFIG/#\~/$HOME}"
[[ "$GHOSTTY_CONFIG" == /* ]] || GHOSTTY_CONFIG="$PWD/$GHOSTTY_CONFIG"
CONFIG_DIR="${GHOSTTY_CONFIG%/*}"
[[ "$CONFIG_DIR" != "$GHOSTTY_CONFIG" ]] || CONFIG_DIR="."
RUNTIME_DIR="$CONFIG_DIR/beautiful-ghostty"

CURSOR_DIR="$SHADERS_DIR/cursor"
BACKGROUND_DIR="$SHADERS_DIR/background"
COMBINED_DIR="$SHADERS_DIR/combined"
GENERATED_DIR="$RUNTIME_DIR/generated"
ACTIVE_CONFIG="$RUNTIME_DIR/active.ghostty"
STATE_FILE="$RUNTIME_DIR/state"

CURSOR_SELECTION=""
BACKGROUND_SELECTION=""
COMBINED_SELECTION=""

CURSOR_ENABLED=0
BACKGROUND_ENABLED=0
COMBINED_ENABLED=0
GPU_PROFILE="quality"
ACTIVE_SHADER_PATHS=()

NO_RELOAD=0

usage() {
  cat <<'USAGE'
Usage:
  beautiful-ghostty [--no-reload] list cursor|background|combined|profiles
  beautiful-ghostty [--no-reload] current cursor|background|combined
  beautiful-ghostty [--no-reload] mode
  beautiful-ghostty [--no-reload] profile
  beautiful-ghostty [--no-reload] status
  beautiful-ghostty [--no-reload] set cursor|background|combined NAME|none
  beautiful-ghostty [--no-reload] set-profile eco|balanced|quality|ultra
  beautiful-ghostty [--no-reload] apply
  beautiful-ghostty reload
  beautiful-ghostty validate
  beautiful-ghostty --version

Shader modes:
  - Separate: cursor and background stages are configured independently.
    Enabling either stage disables the combined stage.
  - Combined: one shader supplies both effects. Enabling it disables both
    separate stages.
  - Selecting "none" disables only the requested stage and never restores or
    changes another stage.
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

print_version() {
  [[ -f "$VERSION_FILE" ]] || fail "missing VERSION file: $VERSION_FILE"
  printf 'Beautiful Ghostty %s\n' "$(<"$VERSION_FILE")"
}

ensure_layout() {
  [[ -d "$SHADERS_DIR" ]] || fail "missing shader directory: $SHADERS_DIR"
  [[ -d "$CURSOR_DIR" ]] || fail "missing cursor directory: $CURSOR_DIR"
  [[ -d "$BACKGROUND_DIR" ]] || fail "missing background directory: $BACKGROUND_DIR"
  [[ -d "$COMBINED_DIR" ]] || fail "missing combined directory: $COMBINED_DIR"
  command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
}

normalize_boolean() {
  [[ "${1:-0}" == "1" ]] && printf '1' || printf '0'
}

valid_profile() {
  case "${1:-}" in
  eco | balanced | quality | ultra) return 0 ;;
  *) return 1 ;;
  esac
}

valid_shader_filename() {
  [[ "${1:-}" =~ ^[A-Za-z0-9._-]+\.glsl$ ]]
}

kind_directory() {
  case "$1" in
  cursor) printf '%s' "$CURSOR_DIR" ;;
  background) printf '%s' "$BACKGROUND_DIR" ;;
  combined) printf '%s' "$COMBINED_DIR" ;;
  *) return 1 ;;
  esac
}

kind_selection() {
  case "$1" in
  cursor) printf '%s' "$CURSOR_SELECTION" ;;
  background) printf '%s' "$BACKGROUND_SELECTION" ;;
  combined) printf '%s' "$COMBINED_SELECTION" ;;
  *) return 1 ;;
  esac
}

kind_enabled() {
  case "$1" in
  cursor) printf '%s' "$CURSOR_ENABLED" ;;
  background) printf '%s' "$BACKGROUND_ENABLED" ;;
  combined) printf '%s' "$COMBINED_ENABLED" ;;
  *) return 1 ;;
  esac
}

kind_display_name() {
  case "$1" in
  cursor) printf 'Cursor' ;;
  background) printf 'Background' ;;
  combined) printf 'Combined' ;;
  *) return 1 ;;
  esac
}

shader_mode() {
  if [[ "$COMBINED_ENABLED" == "1" ]]; then
    printf 'combined'
  elif [[ "$CURSOR_ENABLED" == "1" || "$BACKGROUND_ENABLED" == "1" ]]; then
    printf 'separate'
  else
    printf 'none'
  fi
}

shader_mode_display_name() {
  case "$(shader_mode)" in
  combined) printf 'Combined shader' ;;
  separate) printf 'Separate shaders' ;;
  none) printf 'Off' ;;
  esac
}

load_state() {
  local key value

  [[ -f "$STATE_FILE" ]] || return 0

  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    case "$key" in
    CURSOR_SELECTION) CURSOR_SELECTION="$value" ;;
    BACKGROUND_SELECTION) BACKGROUND_SELECTION="$value" ;;
    COMBINED_SELECTION) COMBINED_SELECTION="$value" ;;
    CURSOR_ENABLED) CURSOR_ENABLED="$value" ;;
    BACKGROUND_ENABLED) BACKGROUND_ENABLED="$value" ;;
    COMBINED_ENABLED) COMBINED_ENABLED="$value" ;;
    GPU_PROFILE) GPU_PROFILE="$value" ;;
    esac
  done <"$STATE_FILE"

  CURSOR_ENABLED="$(normalize_boolean "$CURSOR_ENABLED")"
  BACKGROUND_ENABLED="$(normalize_boolean "$BACKGROUND_ENABLED")"
  COMBINED_ENABLED="$(normalize_boolean "$COMBINED_ENABLED")"

  valid_profile "$GPU_PROFILE" || GPU_PROFILE="quality"

  if [[ -n "$CURSOR_SELECTION" ]] && (! valid_shader_filename "$CURSOR_SELECTION" || [[ ! -f "$CURSOR_DIR/$CURSOR_SELECTION" ]]); then
    CURSOR_SELECTION=""
    CURSOR_ENABLED=0
  fi

  if [[ -n "$BACKGROUND_SELECTION" ]] && (! valid_shader_filename "$BACKGROUND_SELECTION" || [[ ! -f "$BACKGROUND_DIR/$BACKGROUND_SELECTION" ]]); then
    BACKGROUND_SELECTION=""
    BACKGROUND_ENABLED=0
  fi

  if [[ -n "$COMBINED_SELECTION" ]] && (! valid_shader_filename "$COMBINED_SELECTION" || [[ ! -f "$COMBINED_DIR/$COMBINED_SELECTION" ]]); then
    COMBINED_SELECTION=""
    COMBINED_ENABLED=0
  fi

  [[ -n "$CURSOR_SELECTION" ]] || CURSOR_ENABLED=0
  [[ -n "$BACKGROUND_SELECTION" ]] || BACKGROUND_ENABLED=0
  [[ -n "$COMBINED_SELECTION" ]] || COMBINED_ENABLED=0

  if [[ "$COMBINED_ENABLED" == "1" ]]; then
    CURSOR_ENABLED=0
    BACKGROUND_ENABLED=0
  fi
}

save_state() {
  local temporary

  mkdir -p -- "$RUNTIME_DIR"
  temporary="$(mktemp "${STATE_FILE}.tmp.XXXXXX")"

  {
    printf 'CURSOR_SELECTION=%s\n' "$CURSOR_SELECTION"
    printf 'BACKGROUND_SELECTION=%s\n' "$BACKGROUND_SELECTION"
    printf 'COMBINED_SELECTION=%s\n' "$COMBINED_SELECTION"
    printf 'CURSOR_ENABLED=%s\n' "$CURSOR_ENABLED"
    printf 'BACKGROUND_ENABLED=%s\n' "$BACKGROUND_ENABLED"
    printf 'COMBINED_ENABLED=%s\n' "$COMBINED_ENABLED"
    printf 'GPU_PROFILE=%s\n' "$GPU_PROFILE"
  } >"$temporary"

  chmod 0600 "$temporary"
  mv -f -- "$temporary" "$STATE_FILE"
}

load_profile_parameters() {
  case "$GPU_PROFILE" in
  eco)
    GPU_PROFILE_ID=0
    GPU_SPACE_STAR_LAYERS=5
    GPU_GAUSSIAN_STAR_LAYERS=1
    GPU_METEOR_LAYERS=4
    GPU_GEODESIC_STEPS=24
    GPU_FBM_OCTAVES=3
    GPU_CURSOR_SPARKS=0
    ;;

  balanced)
    GPU_PROFILE_ID=1
    GPU_SPACE_STAR_LAYERS=8
    GPU_GAUSSIAN_STAR_LAYERS=2
    GPU_METEOR_LAYERS=8
    GPU_GEODESIC_STEPS=32
    GPU_FBM_OCTAVES=4
    GPU_CURSOR_SPARKS=2
    ;;

  quality)
    GPU_PROFILE_ID=2
    GPU_SPACE_STAR_LAYERS=11
    GPU_GAUSSIAN_STAR_LAYERS=3
    GPU_METEOR_LAYERS=12
    GPU_GEODESIC_STEPS=40
    GPU_FBM_OCTAVES=5
    GPU_CURSOR_SPARKS=4
    ;;

  ultra)
    GPU_PROFILE_ID=3
    GPU_SPACE_STAR_LAYERS=11
    GPU_GAUSSIAN_STAR_LAYERS=4
    GPU_METEOR_LAYERS=18
    GPU_GEODESIC_STEPS=48
    GPU_FBM_OCTAVES=5
    GPU_CURSOR_SPARKS=6
    ;;
  esac
}

profile_display_name() {
  case "$GPU_PROFILE" in
  eco) printf 'Power saver' ;;
  balanced) printf 'Balanced' ;;
  quality) printf 'Quality' ;;
  ultra) printf 'Ultra' ;;
  esac
}

profile_summary() {
  load_profile_parameters

  printf '%s: stars %s, meteors %s, geodesics %s, FBM %s, cursor sparks %s' \
    "$(profile_display_name)" \
    "$GPU_SPACE_STAR_LAYERS" \
    "$GPU_METEOR_LAYERS" \
    "$GPU_GEODESIC_STEPS" \
    "$GPU_FBM_OCTAVES" \
    "$GPU_CURSOR_SPARKS"
}

write_profiled_shader() {
  local source="$1"
  local target="$2"
  local source_tag="$3"
  local temporary first_line

  [[ -f "$source" ]] || fail "missing shader: $source"

  load_profile_parameters
  mkdir -p -- "${target%/*}"
  temporary="$(mktemp "${target}.tmp.XXXXXX")"

  exec 3<"$source"
  if ! IFS= read -r first_line <&3; then
    exec 3<&-
    rm -f -- "$temporary"
    fail "shader is empty: $source"
  fi

  {
    if [[ "$first_line" == \#version* ]]; then
      printf '%s\n' "$first_line"
    fi

    cat <<EOF_HEADER
// beautiful-ghostty:source=$source_tag
// beautiful-ghostty:gpu-profile=$GPU_PROFILE
#define GHOSTTY_GPU_PROFILE_ECO 0
#define GHOSTTY_GPU_PROFILE_BALANCED 1
#define GHOSTTY_GPU_PROFILE_QUALITY 2
#define GHOSTTY_GPU_PROFILE_ULTRA 3
#define GHOSTTY_GPU_PROFILE $GPU_PROFILE_ID
EOF_HEADER

    if [[ "$first_line" != \#version* ]]; then
      printf '%s\n' "$first_line"
    fi
    cat <&3
  } >"$temporary"

  exec 3<&-
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$target"
}

materialize_selection() {
  local source_dir="$1"
  local selection="$2"
  local kind="$3"
  local enabled="$4"
  local digest filename source stem target temporary

  [[ "$enabled" == "1" && -n "$selection" ]] || return 0

  source="$source_dir/$selection"
  stem="${selection%.glsl}"
  mkdir -p -- "$GENERATED_DIR"
  temporary="$(mktemp "$GENERATED_DIR/.shader.XXXXXX")"
  rm -- "$temporary"

  write_profiled_shader "$source" "$temporary" "$kind/$selection"
  digest="$(sha256sum -- "$temporary")"
  digest="${digest%% *}"
  filename="$kind-$stem-$GPU_PROFILE-${digest:0:16}.glsl"
  target="$GENERATED_DIR/$filename"

  if [[ -f "$target" ]]; then
    rm -- "$temporary"
  else
    mv -- "$temporary" "$target"
  fi
  ACTIVE_SHADER_PATHS+=("$target")
}

quote_ghostty_value() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

write_active_config() {
  local path temporary

  temporary="$(mktemp "${ACTIVE_CONFIG}.tmp.XXXXXX")"
  {
    printf '# Generated by beautiful-ghostty; do not edit.\n'
    for path in "${ACTIVE_SHADER_PATHS[@]}"; do
      printf 'custom-shader = %s\n' "$(quote_ghostty_value "$path")"
    done
    ((${#ACTIVE_SHADER_PATHS[@]} == 0)) || printf 'custom-shader-animation = true\n'
  } >"$temporary"
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$ACTIVE_CONFIG"
}

cleanup_generated_shaders() {
  local file filename path
  local -A active=()

  for path in "${ACTIVE_SHADER_PATHS[@]}"; do
    active["${path##*/}"]=1
  done

  shopt -s nullglob
  for file in "$GENERATED_DIR"/*.glsl; do
    filename="${file##*/}"
    [[ -n "${active[$filename]:-}" ]] || rm -- "$file"
  done
  shopt -u nullglob
}

apply_shader_state() {
  ACTIVE_SHADER_PATHS=()
  mkdir -p -- "$GENERATED_DIR"

  if [[ "$COMBINED_ENABLED" == "1" ]]; then
    materialize_selection \
      "$COMBINED_DIR" \
      "$COMBINED_SELECTION" \
      combined \
      "$COMBINED_ENABLED"
  else
    materialize_selection \
      "$BACKGROUND_DIR" \
      "$BACKGROUND_SELECTION" \
      background \
      "$BACKGROUND_ENABLED"

    materialize_selection \
      "$CURSOR_DIR" \
      "$CURSOR_SELECTION" \
      cursor \
      "$CURSOR_ENABLED"
  fi

  write_active_config
  cleanup_generated_shaders
  save_state
}

reload_ghostty() {
  local proc pid process_name
  local signalled=0

  # SIGUSR2 asks every running Ghostty process to reload its configuration.
  for proc in /proc/[0-9]*; do
    [[ -r "$proc/comm" ]] || continue
    IFS= read -r process_name <"$proc/comm" || continue
    [[ "$process_name" == "ghostty" ]] || continue

    pid="${proc##*/}"
    if kill -USR2 "$pid" 2>/dev/null; then
      signalled=1
    fi
  done

  [[ "$signalled" == "1" ]]
}

reload_after_change() {
  [[ "$NO_RELOAD" == "1" ]] && return 0

  if ! reload_ghostty; then
    warn "shader files were updated, but no running Ghostty instance was reloaded"
  fi
}

normalize_shader_argument() {
  local value="$1"

  case "$value" in
  none | off | disabled | -) printf 'none' ;;
  *.glsl) printf '%s' "$value" ;;
  *) printf '%s.glsl' "$value" ;;
  esac
}

set_shader() {
  local kind="$1"
  local requested="$2"
  local directory normalized

  directory="$(kind_directory "$kind")" || fail "invalid shader kind: $kind"
  normalized="$(normalize_shader_argument "$requested")"

  if [[ "$normalized" != "none" ]]; then
    valid_shader_filename "$normalized" || fail "invalid shader filename: $normalized"
    [[ -f "$directory/$normalized" ]] || fail "shader not found: $directory/$normalized"
  fi

  case "$kind" in
  cursor)
    if [[ "$normalized" == "none" ]]; then
      CURSOR_ENABLED=0
    else
      CURSOR_SELECTION="$normalized"
      CURSOR_ENABLED=1
      COMBINED_ENABLED=0
    fi
    ;;

  background)
    if [[ "$normalized" == "none" ]]; then
      BACKGROUND_ENABLED=0
    else
      BACKGROUND_SELECTION="$normalized"
      BACKGROUND_ENABLED=1
      COMBINED_ENABLED=0
    fi
    ;;

  combined)
    if [[ "$normalized" == "none" ]]; then
      COMBINED_ENABLED=0
    else
      COMBINED_SELECTION="$normalized"
      COMBINED_ENABLED=1
      CURSOR_ENABLED=0
      BACKGROUND_ENABLED=0
    fi
    ;;
  esac

  apply_shader_state
  reload_after_change

  if [[ "$normalized" == "none" ]]; then
    if [[ "$kind" == "combined" ]]; then
      printf 'Combined shader disabled. Separate stages were left unchanged and were not restored.\n'
    else
      printf '%s shader disabled. Combined and the other separate stage were left unchanged.\n' \
        "$(kind_display_name "$kind")"
    fi
  elif [[ "$kind" == "combined" ]]; then
    printf 'Combined shader enabled: %s\n' "${normalized%.glsl}"
    printf 'Separate cursor and background shaders were disabled.\n'
  else
    printf '%s shader enabled: %s\n' \
      "$(kind_display_name "$kind")" \
      "${normalized%.glsl}"
    printf 'Combined shader was disabled; the other separate stage was left unchanged.\n'
  fi

  status
}

set_profile() {
  local profile="$1"

  valid_profile "$profile" || fail "invalid GPU profile: $profile"
  GPU_PROFILE="$profile"

  apply_shader_state
  reload_after_change
  profile_summary
  printf '\n'
}

list_shaders() {
  local kind="$1"
  local directory file

  if [[ "$kind" == "profiles" ]]; then
    printf '%s\n' eco balanced quality ultra
    return
  fi

  directory="$(kind_directory "$kind")" || fail "invalid shader kind: $kind"

  shopt -s nullglob
  for file in "$directory"/*.glsl; do
    printf '%s\n' "${file##*/}"
  done
  shopt -u nullglob
}

current_shader() {
  local kind="$1"
  local selection enabled

  selection="$(kind_selection "$kind")" || fail "invalid shader kind: $kind"
  enabled="$(kind_enabled "$kind")" || fail "invalid shader kind: $kind"

  if [[ "$enabled" == "1" && -n "$selection" ]]; then
    printf '%s\n' "$selection"
  else
    printf 'none\n'
  fi
}

status() {
  local cursor background combined

  cursor="none"
  background="none"
  combined="none"

  [[ "$CURSOR_ENABLED" == "1" ]] && cursor="$CURSOR_SELECTION"
  [[ "$BACKGROUND_ENABLED" == "1" ]] && background="$BACKGROUND_SELECTION"
  [[ "$COMBINED_ENABLED" == "1" ]] && combined="$COMBINED_SELECTION"

  printf 'Shader mode: %s (%s)\n' "$(shader_mode_display_name)" "$(shader_mode)"
  printf 'GPU profile: %s (%s)\n' "$(profile_display_name)" "$GPU_PROFILE"
  printf 'Cursor:      %s\n' "$cursor"
  printf 'Background:  %s\n' "$background"
  printf 'Combined:    %s\n' "$combined"
}

validate_config() {
  command -v ghostty >/dev/null 2>&1 || fail "ghostty executable not found"
  [[ -f "$GHOSTTY_CONFIG" ]] || fail "Ghostty config not found: $GHOSTTY_CONFIG"

  ghostty +validate-config --config-file="$GHOSTTY_CONFIG"
}

parse_global_options() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --no-reload)
      NO_RELOAD=1
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --version)
      print_version
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
    esac
  done

  REMAINING_ARGS=("$@")
}

main() {
  local command kind value

  parse_global_options "$@"
  set -- "${REMAINING_ARGS[@]}"

  command="${1:-help}"
  shift || true

  case "$command" in
  help)
    usage
    ;;

  version)
    print_version
    ;;

  list)
    ensure_layout
    kind="${1:-}"
    [[ -n "$kind" ]] || fail "list requires a shader kind or profiles"
    list_shaders "$kind"
    ;;

  current)
    ensure_layout
    load_state
    kind="${1:-}"
    [[ -n "$kind" ]] || fail "current requires cursor, background, or combined"
    current_shader "$kind"
    ;;

  mode)
    ensure_layout
    load_state
    shader_mode
    printf '\n'
    ;;

  profile)
    ensure_layout
    load_state
    printf '%s\n' "$GPU_PROFILE"
    ;;

  status)
    ensure_layout
    load_state
    status
    ;;

  set)
    ensure_layout
    load_state
    kind="${1:-}"
    value="${2:-}"
    [[ -n "$kind" && -n "$value" ]] || fail "set requires KIND and NAME|none"
    set_shader "$kind" "$value"
    ;;

  set-profile)
    ensure_layout
    load_state
    value="${1:-}"
    [[ -n "$value" ]] || fail "set-profile requires eco, balanced, quality, or ultra"
    set_profile "$value"
    ;;

  apply)
    ensure_layout
    load_state
    apply_shader_state
    reload_after_change
    status
    ;;

  reload)
    if reload_ghostty; then
      printf 'Ghostty reloaded.\n'
    else
      fail "no running Ghostty instance could be reloaded"
    fi
    ;;

  validate)
    validate_config
    ;;

  *)
    fail "unknown command: $command"
    ;;
  esac
}

main "$@"
