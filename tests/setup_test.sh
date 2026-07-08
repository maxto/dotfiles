#!/usr/bin/env bash
# Exercise bin/setup in a sandbox HOME. Does not affect the real system.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
export XDG_CONFIG_HOME="$TMP/.config"

# A pre-existing REAL herdr config that must be backed up, and a base bashrc.
mkdir -p "$XDG_CONFIG_HOME/herdr"
echo "OLD" > "$XDG_CONFIG_HOME/herdr/config.toml"
echo "# base bashrc" > "$HOME/.bashrc"

bash "$REPO/bin/setup" >/dev/null

check "herdr config is a symlink into the repo" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" && "$(readlink -f "$XDG_CONFIG_HOME/herdr/config.toml")" == "$REPO/herdr/config.toml" ]]'

check "old real herdr config backed up with original content" \
  '[[ -f "$XDG_CONFIG_HOME/herdr/config.toml.bak" && "$(cat "$XDG_CONFIG_HOME/herdr/config.toml.bak")" == "OLD" ]]'

check "micro bindings linked when target was absent" \
  '[[ -L "$XDG_CONFIG_HOME/micro/bindings.json" ]]'

check "bashrc has the source line" \
  'grep -qxF "source $REPO/shell/bashrc" "$HOME/.bashrc"'

# Second run: must not duplicate the source line, must not re-backup.
bash "$REPO/bin/setup" >/dev/null

check "source line present exactly once after rerun" \
  '[[ "$(grep -cxF "source $REPO/shell/bashrc" "$HOME/.bashrc")" -eq 1 ]]'

check "herdr config still a symlink after rerun" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" ]]'

check "no double backup created on rerun" \
  '[[ ! -e "$XDG_CONFIG_HOME/herdr/config.toml.bak.bak" ]]'

exit $fail
