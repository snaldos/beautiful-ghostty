#!/usr/bin/env bash

set -Eeuo pipefail

# =============================================================================
# Ghostty shader manager
# =============================================================================
#
# UI-independent backend for selecting cursor, background, and combined Ghostty
# shaders and materializing a compile-time GPU profile into the active files.
#
# It intentionally has no Fuzzel, Rofi, Hyprland, or notification dependency.
# A desktop-specific launcher can call this script with command-line arguments.
#
# Expected layout beside this script:
#
#   shaders/
#   ├── background/*.glsl
#   ├── combined/*.glsl
#   ├── cursor/*.glsl
#   ├── custom_background.glsl
#   ├── custom_combined.glsl
#   └── custom_cursor.glsl
#
# Recommended Ghostty config order, using absolute paths:
#
#   custom-shader = /path/to/beautiful-ghostty/shaders/custom_background.glsl
#   custom-shader = /path/to/beautiful-ghostty/shaders/custom_cursor.glsl
#   custom-shader = /path/to/beautiful-ghostty/shaders/custom_combined.glsl
#   custom-shader-animation = true
#
# Commands:
#
#   ghostty-shaders.sh list cursor|background|combined|profiles
#   ghostty-shaders.sh current cursor|background|combined
#   ghostty-shaders.sh profile
#   ghostty-shaders.sh status
#   ghostty-shaders.sh set cursor|background|combined NAME|none
#   ghostty-shaders.sh set-profile eco|balanced|quality|ultra
#   ghostty-shaders.sh reload
#   ghostty-shaders.sh validate
#
# Global option:
#
#   --no-reload   Update files without reloading running Ghostty instances.
#
# Environment overrides:
#
#   GHOSTTY_CONFIG       Exact Ghostty config used by `validate`.
#   GHOSTTY_CONFIG_DIR   Directory searched for config.ghostty or legacy config.
#
# =============================================================================

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
[[ "$SCRIPT_DIR" == "$SCRIPT_PATH" ]] && SCRIPT_DIR="."
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

# Shader sources and generated files always live beside this script, regardless
# of where the repository was cloned.
SHADERS_DIR="$SCRIPT_DIR/shaders"

resolve_default_config() {
  local config_dir

  config_dir="${GHOSTTY_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ghostty}"
  config_dir="${config_dir/#\~/$HOME}"

  if [[ -f "$config_dir/config.ghostty" ]]; then
    printf '%s' "$config_dir/config.ghostty"
  elif [[ -f "$config_dir/config" ]]; then
    printf '%s' "$config_dir/config"
  else
    printf '%s' "$config_dir/config.ghostty"
  fi
}

if [[ -n "${GHOSTTY_CONFIG:-}" ]]; then
  GHOSTTY_CONFIG="${GHOSTTY_CONFIG/#\~/$HOME}"
else
  GHOSTTY_CONFIG="$(resolve_default_config)"
fi
CURSOR_DIR="$SHADERS_DIR/cursor"
BACKGROUND_DIR="$SHADERS_DIR/background"
COMBINED_DIR="$SHADERS_DIR/combined"

CUSTOM_CURSOR="$SHADERS_DIR/custom_cursor.glsl"
CUSTOM_BACKGROUND="$SHADERS_DIR/custom_background.glsl"
CUSTOM_COMBINED="$SHADERS_DIR/custom_combined.glsl"
STATE_FILE="$SHADERS_DIR/.shader-selection"

NOOP_MARKER="ghostty-theme-script:no-op"
SOURCE_MARKER="// ghostty-theme-script:source="
PROFILE_MARKER="// ghostty-theme-script:gpu-profile="

CURSOR_SELECTION=""
BACKGROUND_SELECTION=""
COMBINED_SELECTION=""

CURSOR_ENABLED=0
BACKGROUND_ENABLED=0
COMBINED_ENABLED=0
GPU_PROFILE="quality"

NO_RELOAD=0

usage() {
  cat <<'USAGE'
Usage:
  ghostty-shaders.sh [--no-reload] list cursor|background|combined|profiles
  ghostty-shaders.sh [--no-reload] current cursor|background|combined
  ghostty-shaders.sh [--no-reload] profile
  ghostty-shaders.sh [--no-reload] status
  ghostty-shaders.sh [--no-reload] set cursor|background|combined NAME|none
  ghostty-shaders.sh [--no-reload] set-profile eco|balanced|quality|ultra
  ghostty-shaders.sh reload
  ghostty-shaders.sh validate

Selection rules:
  - Selecting a cursor disables the combined stage and leaves the background
    stage unchanged.
  - Selecting a background disables the combined stage and leaves the cursor
    stage unchanged.
  - Selecting a combined shader disables both separate stages.
  - Selecting "none" disables the selected stage.
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

ensure_layout() {
  [[ -d "$SHADERS_DIR" ]] || fail "missing shader directory: $SHADERS_DIR"
  [[ -d "$CURSOR_DIR" ]] || fail "missing cursor directory: $CURSOR_DIR"
  [[ -d "$BACKGROUND_DIR" ]] || fail "missing background directory: $BACKGROUND_DIR"
  [[ -d "$COMBINED_DIR" ]] || fail "missing combined directory: $COMBINED_DIR"
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

is_noop_shader() {
  local target="$1"
  local line

  [[ -f "$target" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *"$NOOP_MARKER"* ]] && return 0
  done <"$target"

  return 1
}

marker_value() {
  local target="$1"
  local prefix="$2"
  local line

  [[ -f "$target" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$prefix"* ]]; then
      printf '%s' "${line#"$prefix"}"
      return 0
    fi
  done <"$target"
}

selection_from_target() {
  local target="$1"
  local kind="$2"
  local directory="$3"
  local marker selection file

  marker="$(marker_value "$target" "$SOURCE_MARKER")"

  case "$marker" in
  "$kind/"*.glsl)
    selection="${marker#"$kind/"}"
    if valid_shader_filename "$selection" && [[ -f "$directory/$selection" ]]; then
      printf '%s' "$selection"
      return 0
    fi
    ;;
  esac

  # Compatibility with old, unprofiled copies when cmp is available.
  if command -v cmp >/dev/null 2>&1 && [[ -f "$target" ]] && ! is_noop_shader "$target"; then
    shopt -s nullglob
    for file in "$directory"/*.glsl; do
      if cmp -s -- "$file" "$target"; then
        printf '%s' "${file##*/}"
        shopt -u nullglob
        return 0
      fi
    done
    shopt -u nullglob
  fi
}

detect_profile_from_targets() {
  local target profile

  for target in "$CUSTOM_COMBINED" "$CUSTOM_BACKGROUND" "$CUSTOM_CURSOR"; do
    profile="$(marker_value "$target" "$PROFILE_MARKER")"
    if valid_profile "$profile"; then
      printf '%s' "$profile"
      return 0
    fi
  done

  printf 'quality'
}

bootstrap_state() {
  CURSOR_SELECTION="$(selection_from_target "$CUSTOM_CURSOR" cursor "$CURSOR_DIR")"
  BACKGROUND_SELECTION="$(selection_from_target "$CUSTOM_BACKGROUND" background "$BACKGROUND_DIR")"
  COMBINED_SELECTION="$(selection_from_target "$CUSTOM_COMBINED" combined "$COMBINED_DIR")"
  GPU_PROFILE="$(detect_profile_from_targets)"

  CURSOR_ENABLED=0
  BACKGROUND_ENABLED=0
  COMBINED_ENABLED=0

  if [[ -n "$COMBINED_SELECTION" ]] && [[ -f "$CUSTOM_COMBINED" ]] && ! is_noop_shader "$CUSTOM_COMBINED"; then
    COMBINED_ENABLED=1
    return
  fi

  if [[ -n "$CURSOR_SELECTION" ]] && [[ -f "$CUSTOM_CURSOR" ]] && ! is_noop_shader "$CUSTOM_CURSOR"; then
    CURSOR_ENABLED=1
  fi

  if [[ -n "$BACKGROUND_SELECTION" ]] && [[ -f "$CUSTOM_BACKGROUND" ]] && ! is_noop_shader "$CUSTOM_BACKGROUND"; then
    BACKGROUND_ENABLED=1
  fi
}

load_state() {
  local key value

  if [[ ! -f "$STATE_FILE" ]]; then
    bootstrap_state
    return
  fi

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

  mkdir -p -- "$SHADERS_DIR"
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

write_noop_shader() {
  local target="$1"
  local temporary

  mkdir -p -- "${target%/*}"
  temporary="$(mktemp "${target}.tmp.XXXXXX")"

  cat >"$temporary" <<'GLSL'
// ghostty-theme-script:no-op
// Pass the previous shader stage through unchanged.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / max(iResolution.xy, vec2(1.0));
    fragColor = texture(iChannel0, uv);
}
GLSL

  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$target"
}

replacement_for_define() {
  case "$1" in
  SPACE_STAR_LAYERS) printf '%s' "$GPU_SPACE_STAR_LAYERS" ;;
  STAR_LAYERS) printf '%s' "$GPU_GAUSSIAN_STAR_LAYERS" ;;
  METEOR_LAYERS) printf '%s' "$GPU_METEOR_LAYERS" ;;
  N_STEPS) printf '%s' "$GPU_GEODESIC_STEPS" ;;
  SPARK_COUNT) printf '%s' "$GPU_CURSOR_SPARKS" ;;
  *) return 1 ;;
  esac
}

# Rewrite a shader using Bash pattern matching only. Source files are untouched.
write_profiled_shader() {
  local source="$1"
  local target="$2"
  local source_tag="$3"
  local temporary first_line line rewritten replacement name
  local in_fbm=0
  local fbm_depth=0
  local fbm_seen_brace=0
  local index character

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
// ghostty-theme-script:source=$source_tag
// ghostty-theme-script:gpu-profile=$GPU_PROFILE
#define GHOSTTY_GPU_PROFILE_ECO 0
#define GHOSTTY_GPU_PROFILE_BALANCED 1
#define GHOSTTY_GPU_PROFILE_QUALITY 2
#define GHOSTTY_GPU_PROFILE_ULTRA 3
#define GHOSTTY_GPU_PROFILE $GPU_PROFILE_ID
#define GHOSTTY_FBM_OCTAVES $GPU_FBM_OCTAVES
EOF_HEADER

    process_line() {
      line="$1"
      rewritten="$line"

      if [[ "$line" =~ ^([[:space:]]*#[[:space:]]*define[[:space:]]+)(SPACE_STAR_LAYERS|STAR_LAYERS|METEOR_LAYERS|N_STEPS|SPARK_COUNT)([[:space:]]+)([^[:space:]]+)(.*)$ ]]; then
        name="${BASH_REMATCH[2]}"
        replacement="$(replacement_for_define "$name")"
        rewritten="${BASH_REMATCH[1]}${name}${BASH_REMATCH[3]}${replacement}${BASH_REMATCH[5]}"
      fi

      if [[ "$line" =~ ^[[:space:]]*float[[:space:]]+fbm[[:space:]]*\( ]]; then
        in_fbm=1
        fbm_depth=0
        fbm_seen_brace=0
      fi

      if [[ "$in_fbm" == "1" ]] && [[ "$rewritten" =~ ^([[:space:]]*for[[:space:]]*\([[:space:]]*int[[:space:]]+i[[:space:]]*=[[:space:]]*0[[:space:]]*\;[[:space:]]*i[[:space:]]*\<[[:space:]]*)[0-9]+([[:space:]]*\;[[:space:]]*i\+\+[[:space:]]*\).*)$ ]]; then
        rewritten="${BASH_REMATCH[1]}GHOSTTY_FBM_OCTAVES${BASH_REMATCH[2]}"
      fi

      printf '%s\n' "$rewritten"

      if [[ "$in_fbm" == "1" ]]; then
        for ((index = 0; index < ${#rewritten}; index += 1)); do
          character="${rewritten:index:1}"
          if [[ "$character" == "{" ]]; then
            fbm_depth=$((fbm_depth + 1))
            fbm_seen_brace=1
          elif [[ "$character" == "}" ]]; then
            fbm_depth=$((fbm_depth - 1))
          fi
        done

        if [[ "$fbm_seen_brace" == "1" && "$fbm_depth" -le 0 ]]; then
          in_fbm=0
        fi
      fi
    }

    if [[ "$first_line" != \#version* ]]; then
      process_line "$first_line"
    fi

    while IFS= read -r line <&3 || [[ -n "$line" ]]; do
      process_line "$line"
    done
  } >"$temporary"

  exec 3<&-
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$target"
}

materialize_selection() {
  local source_dir="$1"
  local selection="$2"
  local target="$3"
  local kind="$4"
  local enabled="$5"

  if [[ "$enabled" != "1" || -z "$selection" ]]; then
    write_noop_shader "$target"
    return
  fi

  write_profiled_shader \
    "$source_dir/$selection" \
    "$target" \
    "$kind/$selection"
}

apply_shader_state() {
  if [[ "$COMBINED_ENABLED" == "1" ]]; then
    write_noop_shader "$CUSTOM_BACKGROUND"
    write_noop_shader "$CUSTOM_CURSOR"

    materialize_selection \
      "$COMBINED_DIR" \
      "$COMBINED_SELECTION" \
      "$CUSTOM_COMBINED" \
      combined \
      "$COMBINED_ENABLED"
  else
    materialize_selection \
      "$BACKGROUND_DIR" \
      "$BACKGROUND_SELECTION" \
      "$CUSTOM_BACKGROUND" \
      background \
      "$BACKGROUND_ENABLED"

    materialize_selection \
      "$CURSOR_DIR" \
      "$CURSOR_SELECTION" \
      "$CUSTOM_CURSOR" \
      cursor \
      "$CURSOR_ENABLED"

    write_noop_shader "$CUSTOM_COMBINED"
  fi

  save_state
}

reload_ghostty() {
  local proc pid process_name
  local signalled=0

  # Preferred Linux path when Ghostty is managed by its user systemd service.
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl reload --user app-com.mitchellh.ghostty.service >/dev/null 2>&1; then
      return 0
    fi
  fi

  # Dependency-free Bash fallback: signal every process whose /proc comm name
  # is exactly "ghostty". SIGUSR2 asks Ghostty to reload its configuration.
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
    fi
    COMBINED_ENABLED=0
    ;;

  background)
    if [[ "$normalized" == "none" ]]; then
      BACKGROUND_ENABLED=0
    else
      BACKGROUND_SELECTION="$normalized"
      BACKGROUND_ENABLED=1
    fi
    COMBINED_ENABLED=0
    ;;

  combined)
    if [[ "$normalized" == "none" ]]; then
      COMBINED_ENABLED=0
    else
      COMBINED_SELECTION="$normalized"
      COMBINED_ENABLED=1
    fi
    CURSOR_ENABLED=0
    BACKGROUND_ENABLED=0
    ;;
  esac

  apply_shader_state
  reload_after_change

  if [[ "$normalized" == "none" ]]; then
    printf '%s shader: None\n' "$kind"
  else
    printf '%s shader: %s\n' "$kind" "${normalized%.glsl}"
  fi
  printf 'GPU profile: %s\n' "$(profile_display_name)"
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
