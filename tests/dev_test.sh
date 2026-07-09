#!/usr/bin/env bash
# Live integration test for bin/dev. Builds the preset around a throwaway
# --no-focus workspace (so it never steals your focus), asserts the geometry
# (70/30 . 40/60), that broot runs bottom-right, and that the agent pane is
# focused, then removes the workspace. Requires a running herdr server.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
# rounded integer percentage of $1 out of $2
pct() { awk "BEGIN{printf \"%d\", ($1*100.0)/$2 + 0.5}"; }

command -v jq    >/dev/null || { echo "jq required";    exit 2; }
command -v herdr >/dev/null || { echo "herdr required"; exit 2; }

WSID="$(herdr workspace create --no-focus --label devtest | jq -r '.result.workspace.workspace_id')"
trap 'herdr workspace close "$WSID" >/dev/null 2>&1' EXIT
anchor="${WSID}:p1"

# Build around the throwaway anchor (explicit pane arg = no focus theft).
bash "$REPO/bin/dev" "$anchor" >/dev/null

layout="$(herdr pane layout --pane "$anchor")"
area_w="$(echo "$layout" | jq -r '.result.layout.area.width')"
area_h="$(echo "$layout" | jq -r '.result.layout.area.height')"
npanes="$(echo "$layout" | jq -r '.result.layout.panes | length')"
focused="$(echo "$layout" | jq -r '.result.layout.focused_pane_id')"

ok "three panes built" '[[ "$npanes" -eq 3 ]]'

aw="$(echo "$layout" | jq -r --arg p "$anchor" '.result.layout.panes[]|select(.pane_id==$p)|.rect.width')"
ah="$(echo "$layout" | jq -r --arg p "$anchor" '.result.layout.panes[]|select(.pane_id==$p)|.rect.height')"
aw_pct="$(pct "$aw" "$area_w")"
ok "agent pane ~70% width (got ${aw_pct}%)" '[[ "$aw_pct" -ge 66 && "$aw_pct" -le 74 ]]'
ok "agent pane spans full height" '[[ "$ah" -eq "$area_h" ]]'

# The two non-anchor panes are the right column; find which runs broot.
right_ids="$(echo "$layout" | jq -r --arg p "$anchor" '.result.layout.panes[]|select(.pane_id!=$p)|.pane_id')"
# broot registers as the foreground process ~1-2s after launch; poll for it.
broot_id=""; bash_id=""
for _ in $(seq 1 20); do
  broot_id=""
  for pid in $right_ids; do
    if herdr pane process-info --pane "$pid" \
         | jq -e '.result.process_info.foreground_processes[]?|select(.name=="broot")' >/dev/null; then
      broot_id="$pid"
    fi
  done
  [[ -n "$broot_id" ]] && break
  sleep 0.5
done
for pid in $right_ids; do
  [[ "$pid" != "$broot_id" ]] && bash_id="$pid"
done
ok "broot running in a right pane" '[[ -n "$broot_id" ]]'
ok "bash shell in the other right pane" '[[ -n "$bash_id" ]]'

bh="$(echo "$layout" | jq -r --arg p "$broot_id" '.result.layout.panes[]?|select(.pane_id==$p)|.rect.height')"
by="$(echo "$layout" | jq -r --arg p "$broot_id" '.result.layout.panes[]?|select(.pane_id==$p)|.rect.y')"
oy="$(echo "$layout" | jq -r --arg p "$bash_id"  '.result.layout.panes[]?|select(.pane_id==$p)|.rect.y')"
bh_pct="$(pct "${bh:-0}" "$area_h")"
ok "broot pane ~60% height (got ${bh_pct}%)" '[[ "$bh_pct" -ge 55 && "$bh_pct" -le 65 ]]'
ok "broot sits below bash (greater y)" '[[ "${by:-0}" -gt "${oy:-0}" ]]'

ok "agent pane is focused" '[[ "$focused" == "$anchor" ]]'

exit $fail
