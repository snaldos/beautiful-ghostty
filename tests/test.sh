#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected absent path: $1"
}

make_fake_ghostty() {
  local bin_dir="$1"

  mkdir -p -- "$bin_dir"
  cat >"$bin_dir/ghostty" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${FAKE_GHOSTTY_FAIL:-0}" == 0 ]] || exit 1
[[ "${1:-}" == +validate-config ]] || exit 0
config=""
for argument in "$@"; do
  case "$argument" in --config-file=*) config="${argument#*=}" ;; esac
done
[[ -n "$config" && -f "$config" ]]
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    'config-file = ?"'*)
      include="${line#'config-file = ?"'}"
      include="${include%\"}"
      [[ -f "$include" ]]
      ;;
  esac
done <"$config"
MOCK
  chmod 0755 "$bin_dir/ghostty"
}

run_install() {
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" PATH="$FAKE_BIN:$PATH" \
    "$ROOT/install.sh" --no-reload "$@"
}

run_uninstall() {
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" PATH="$FAKE_BIN:$PATH" \
    "$ROOT/uninstall.sh" --no-reload "$@"
}

for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/ghostty-shaders.sh"; do
  bash -n "$script"
done

TEST_HOME="$TEMP_ROOT/home with space"
FAKE_BIN="$TEMP_ROOT/fake-bin"
CONFIG="$TEST_HOME/.config/ghostty/config.ghostty"
INSTALL_DIR="$TEST_HOME/.local/share/beautiful-ghostty"
COMMAND="$TEST_HOME/.local/bin/beautiful-ghostty"
RUNTIME="$TEST_HOME/.config/ghostty/beautiful-ghostty"
make_fake_ghostty "$FAKE_BIN"
mkdir -p -- "${CONFIG%/*}"
cat >"$CONFIG" <<'CONFIG'
font-size = 12
custom-shader = /user/owned/shader.glsl
CONFIG
chmod 0600 "$CONFIG"
original_hash="$(sha256sum -- "$CONFIG")"
original_hash="${original_hash%% *}"

run_install >/dev/null
[[ "$(stat -c %a "$CONFIG")" == 600 ]]
assert_file "$INSTALL_DIR/.installed-by-beautiful-ghostty"
assert_file "$INSTALL_DIR/ghostty-shaders.sh"
assert_file "$INSTALL_DIR/shaders/background/cosmos.glsl"
assert_file "$INSTALL_DIR/shaders/background/cosmos_wallpaper.glsl"
assert_file "$INSTALL_DIR/shaders/combined/cosmos.glsl"
assert_file "$INSTALL_DIR/shaders/combined/cosmos_wallpaper.glsl"
assert_file "$INSTALL_DIR/shaders/cursor/cosmic.glsl"
assert_file "$COMMAND"
[[ "$(HOME="$TEST_HOME" "$COMMAND" --version)" == 'Beautiful Ghostty 1.1.0' ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" list background)" == $'cosmos.glsl\ncosmos_wallpaper.glsl' ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" list combined)" == $'cosmos.glsl\ncosmos_wallpaper.glsl' ]]
assert_file "$RUNTIME/state"
assert_file "$RUNTIME/active.ghostty"
[[ "$(grep -Fc '# BEGIN beautiful-ghostty' "$CONFIG")" == 1 ]]
grep -Fq 'custom-shader = /user/owned/shader.glsl' "$CONFIG"
[[ "$(HOME="$TEST_HOME" "$COMMAND" mode)" == combined ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" profile)" == quality ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" current combined)" == cosmos.glsl ]]
mapfile -t active_paths < <(awk -F'"' '/^custom-shader =/ {print $2}' "$RUNTIME/active.ghostty")
[[ "${#active_paths[@]}" == 1 ]]
assert_file "${active_paths[0]}"
[[ "$(find "$RUNTIME/generated" -maxdepth 1 -type f -name '*.glsl' | wc -l)" == 1 ]]

HOME="$TEST_HOME" "$COMMAND" --no-reload set combined cosmos_wallpaper >/dev/null
[[ "$(HOME="$TEST_HOME" "$COMMAND" current combined)" == cosmos_wallpaper.glsl ]]
grep -Fq 'beautiful-ghostty:source=combined/cosmos_wallpaper.glsl' "$RUNTIME/generated/"*.glsl

HOME="$TEST_HOME" "$COMMAND" --no-reload set background cosmos_wallpaper >/dev/null
HOME="$TEST_HOME" "$COMMAND" --no-reload set cursor cosmic >/dev/null
HOME="$TEST_HOME" "$COMMAND" --no-reload set-profile eco >/dev/null
[[ "$(HOME="$TEST_HOME" "$COMMAND" mode)" == separate ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" profile)" == eco ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" current background)" == cosmos_wallpaper.glsl ]]
mapfile -t active_paths < <(awk -F'"' '/^custom-shader =/ {print $2}' "$RUNTIME/active.ghostty")
[[ "${#active_paths[@]}" == 2 ]]
for path in "${active_paths[@]}"; do assert_file "$path"; done
[[ "$(find "$RUNTIME/generated" -maxdepth 1 -type f -name '*.glsl' | wc -l)" == 2 ]]

backup_count_before="$(find "${CONFIG%/*}" -maxdepth 1 -type f -name 'config.ghostty.bak.*' | wc -l)"
run_install >/dev/null
backup_count_after="$(find "${CONFIG%/*}" -maxdepth 1 -type f -name 'config.ghostty.bak.*' | wc -l)"
[[ "$backup_count_before" == "$backup_count_after" ]]
[[ "$(grep -Fc '# BEGIN beautiful-ghostty' "$CONFIG")" == 1 ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" mode)" == separate ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" profile)" == eco ]]

run_uninstall >/dev/null
[[ "$(stat -c %a "$CONFIG")" == 600 ]]
assert_absent "$INSTALL_DIR"
assert_absent "$COMMAND"
assert_file "$RUNTIME/state"
! grep -Fq '# BEGIN beautiful-ghostty' "$CONFIG"
grep -Fq 'custom-shader = /user/owned/shader.glsl' "$CONFIG"

run_install >/dev/null
[[ "$(HOME="$TEST_HOME" "$COMMAND" mode)" == separate ]]
[[ "$(HOME="$TEST_HOME" "$COMMAND" profile)" == eco ]]
run_uninstall --purge >/dev/null
assert_absent "$RUNTIME"

ROLLBACK_HOME="$TEMP_ROOT/rollback-home"
ROLLBACK_CONFIG="$ROLLBACK_HOME/.config/ghostty/config.ghostty"
mkdir -p -- "${ROLLBACK_CONFIG%/*}"
printf 'font-size = 13\n' >"$ROLLBACK_CONFIG"
rollback_before="$(sha256sum -- "$ROLLBACK_CONFIG")"
rollback_before="${rollback_before%% *}"
if HOME="$ROLLBACK_HOME" XDG_CONFIG_HOME="$ROLLBACK_HOME/.config" \
  XDG_DATA_HOME="$ROLLBACK_HOME/.local/share" PATH="$FAKE_BIN:$PATH" \
  FAKE_GHOSTTY_FAIL=1 "$ROOT/install.sh" --no-reload >/dev/null 2>&1; then
  fail "installer succeeded despite validator failure"
fi
rollback_after="$(sha256sum -- "$ROLLBACK_CONFIG")"
rollback_after="${rollback_after%% *}"
[[ "$rollback_before" == "$rollback_after" ]]
assert_absent "$ROLLBACK_HOME/.local/share/beautiful-ghostty"
assert_absent "$ROLLBACK_HOME/.local/bin/beautiful-ghostty"
assert_absent "$ROLLBACK_HOME/.config/ghostty/beautiful-ghostty"

SYMLINK_HOME="$TEMP_ROOT/symlink-home"
SYMLINK_SOURCE="$TEMP_ROOT/config-source/config.ghostty"
mkdir -p -- "$SYMLINK_HOME/.config/ghostty" "${SYMLINK_SOURCE%/*}"
printf 'font-size = 14\n' >"$SYMLINK_SOURCE"
ln -s -- "$SYMLINK_SOURCE" "$SYMLINK_HOME/.config/ghostty/config.ghostty"
HOME="$SYMLINK_HOME" XDG_CONFIG_HOME="$SYMLINK_HOME/.config" \
  XDG_DATA_HOME="$SYMLINK_HOME/.local/share" PATH="$FAKE_BIN:$PATH" \
  "$ROOT/install.sh" --no-reload >/dev/null
[[ -L "$SYMLINK_HOME/.config/ghostty/config.ghostty" ]]
grep -Fq '# BEGIN beautiful-ghostty' "$SYMLINK_SOURCE"
HOME="$SYMLINK_HOME" XDG_CONFIG_HOME="$SYMLINK_HOME/.config" \
  XDG_DATA_HOME="$SYMLINK_HOME/.local/share" PATH="$FAKE_BIN:$PATH" \
  "$ROOT/uninstall.sh" --no-reload --purge >/dev/null
[[ -L "$SYMLINK_HOME/.config/ghostty/config.ghostty" ]]
! grep -Fq '# BEGIN beautiful-ghostty' "$SYMLINK_SOURCE"

printf 'PASS install, upgrade, manager, uninstall, purge, symlink safety, path quoting, and rollback\n'
