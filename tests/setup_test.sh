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

check "bin/setup is executable" \
  '[[ -x "$REPO/bin/setup" ]]'

check "herdr config linked into repo" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" && "$(readlink -f "$XDG_CONFIG_HOME/herdr/config.toml")" == "$REPO/herdr/config.toml" ]]'

check "old real herdr config backed up with original content" \
  '[[ -f "$XDG_CONFIG_HOME/herdr/config.toml.bak" && "$(cat "$XDG_CONFIG_HOME/herdr/config.toml.bak")" == "OLD" ]]'

check "broot config linked into repo" \
  '[[ -L "$XDG_CONFIG_HOME/broot/conf.toml" && "$(readlink -f "$XDG_CONFIG_HOME/broot/conf.toml")" == "$REPO/broot/conf.toml" ]]'

check "micro settings linked into repo" \
  '[[ -L "$XDG_CONFIG_HOME/micro/settings.json" && "$(readlink -f "$XDG_CONFIG_HOME/micro/settings.json")" == "$REPO/micro/settings.json" ]]'

check "micro bindings linked into repo" \
  '[[ -L "$XDG_CONFIG_HOME/micro/bindings.json" && "$(readlink -f "$XDG_CONFIG_HOME/micro/bindings.json")" == "$REPO/micro/bindings.json" ]]'

check "bashrc has the source line" \
  'grep -qxF "source $REPO/shell/bashrc" "$HOME/.bashrc"'

check "existing bashrc content preserved" \
  'grep -qxF "# base bashrc" "$HOME/.bashrc"'

# Second run: must not duplicate the source line, must not re-backup.
bash "$REPO/bin/setup" >/dev/null

check "source line present exactly once after rerun" \
  '[[ "$(grep -cxF "source $REPO/shell/bashrc" "$HOME/.bashrc")" -eq 1 ]]'

check "herdr config still a symlink after rerun" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" ]]'

check "no double backup created on rerun" \
  '[[ ! -e "$XDG_CONFIG_HOME/herdr/config.toml.bak.bak" ]]'

# Non-destructive: a pre-existing .bak must never be clobbered.
# Make broot's link stale (points nowhere) so the backup branch runs again,
# and plant a prior backup that must survive.
STALE="$XDG_CONFIG_HOME/broot/conf.toml"
rm -f "$STALE"
ln -s /nonexistent "$STALE"
echo "PRIOR" > "$STALE.bak"
bash "$REPO/bin/setup" >/dev/null

check "prior .bak preserved (not clobbered)" \
  '[[ "$(cat "$STALE.bak")" == "PRIOR" ]]'
check "broot relinked into repo after stale link" \
  '[[ -L "$STALE" && "$(readlink -f "$STALE")" == "$REPO/broot/conf.toml" ]]'

# Non-destructive against a dangling-symlink backup: a .bak that is itself a
# broken symlink must also survive (not be overwritten by the new backup).
STALE2="$XDG_CONFIG_HOME/micro/settings.json"
rm -f "$STALE2" "$STALE2.bak"
ln -s /nonexistent-a "$STALE2.bak"   # prior backup is itself a dangling symlink
ln -s /nonexistent-b "$STALE2"       # stale target -> triggers the backup branch
bash "$REPO/bin/setup" >/dev/null

check "dangling .bak not clobbered" \
  '[[ "$(readlink "$STALE2.bak")" == "/nonexistent-a" ]]'
check "micro settings relinked after stale link" \
  '[[ -L "$STALE2" && "$(readlink -f "$STALE2")" == "$REPO/micro/settings.json" ]]'

exit $fail
