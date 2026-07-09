# dotfiles Phase 2 (Layout Preset) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `bin/dev`, a script that builds the herdr layout preset — left 70% agent shell, right 30% split into top 40% bash and bottom 60% broot — idempotently in the current tab.

**Architecture:** herdr has no declarative startup layout; the layout is built imperatively over herdr's socket API (JSON out, parsed with `jq`). `bin/dev` resolves an anchor pane (the focused pane, or an explicit `PANE_ID` argument), collapses that pane's tab to a single pane, then performs two splits and launches broot. The explicit-argument path exists so an integration test can build the layout around a throwaway `--no-focus` workspace without stealing the user's focus.

**Tech Stack:** bash, `jq`, herdr `0.7.2` socket API, broot.

## Global Constraints

- Platform: WSL2 Ubuntu; Linux filesystem only. Do not write to `/mnt/c`.
- Language: all code, comments, docs in **English**; short names.
- `bin/dev` must be **idempotent against the current tab**: collapse the tab to one pane, then rebuild. Re-running yields the same clean preset.
- **Verified herdr ratio semantics (do not re-derive):** `--ratio` is the fraction kept by the *original* pane; the new pane gets `1 − ratio`. Therefore left/right = `--direction right --ratio 0.70`; top/bottom = `--direction down --ratio 0.40`.
- Verified JSON paths: `herdr pane current` → `.result.pane.pane_id`; `herdr pane get <id>` → `.result.pane.{workspace_id,tab_id}`; `herdr workspace create` → `.result.workspace.workspace_id`; `herdr pane split ...` → `.result.pane.pane_id`; `herdr pane list --workspace <id>` → `.result.panes[]` (each has `.pane_id`, `.tab_id`); `herdr pane layout --pane <id>` → `.result.layout.area.{width,height}`, `.result.layout.panes[].rect.{x,y,width,height}`, `.result.layout.focused_pane_id`; `herdr pane process-info --pane <id>` → `.result.process_info.foreground_processes[].name`.
- Left and top-right panes stay plain bash shells; broot auto-launches bottom-right. The agent is launched manually by the user — `bin/dev` is agent-agnostic.
- `bin/dev` requires `jq` and `herdr`; it must error clearly (exit 1) if either is missing.

---

### Task 1: `bin/dev` layout script + live integration test + README

**Files:**
- Create: `bin/dev`
- Create: `tests/dev_test.sh`
- Modify: `README.md` (document the `dev` preset)

**Interfaces:**
- Consumes: a running herdr `0.7.2` server (the socket API), `jq`, `broot` — all present on the target machine.
- Produces: `bin/dev [PANE_ID]` — with no argument it builds around the focused pane; with a pane id it builds around that pane. `tests/dev_test.sh` — a live integration test that builds the preset in a throwaway workspace and asserts geometry/behavior.

> **Note on TDD here:** there is no headless herdr in CI; the "test" is a live integration test that drives the real herdr server but isolates itself in a throwaway `--no-focus` workspace it creates and removes, so it never disturbs the user's session. Write the test first, watch it fail (no `bin/dev`), then implement.

- [ ] **Step 1: Write the failing integration test**

Create `tests/dev_test.sh`:

```bash
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
# broot registers as the foreground process ~1-2s after launch, so poll for it.
right_ids="$(echo "$layout" | jq -r --arg p "$anchor" '.result.layout.panes[]|select(.pane_id!=$p)|.pane_id')"
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/dev_test.sh`
Expected: creates the throwaway workspace, then FAILs because `bin/dev` does not exist yet (`bash: .../bin/dev: No such file or directory`), so the geometry checks FAIL. The `trap` still removes the `devtest` workspace on exit. Confirm with `herdr workspace list` that no `devtest` workspace lingers.

- [ ] **Step 3: Write `bin/dev`**

```bash
#!/usr/bin/env bash
# Build the herdr "dev" layout preset in a tab:
#   left 70% = agent (plain shell) | right 30%: top 40% = bash, bottom 60% = broot
# Idempotent: collapses the target tab to a single pane, then rebuilds
# (re-run = reset). Usage: dev [PANE_ID]  (default: the focused pane).
set -euo pipefail

command -v jq    >/dev/null || { echo "dev: jq is required"    >&2; exit 1; }
command -v herdr >/dev/null || { echo "dev: herdr is required" >&2; exit 1; }

# 1. Anchor pane (becomes left/agent) and its tab.
if [[ $# -ge 1 ]]; then
  anchor="$1"
else
  anchor="$(herdr pane current | jq -r '.result.pane.pane_id')"
fi
info="$(herdr pane get "$anchor")"
wsid="$(echo "$info" | jq -r '.result.pane.workspace_id')"
tabid="$(echo "$info" | jq -r '.result.pane.tab_id')"

# 2. Collapse the tab: close every pane in it except the anchor. The pane list is
#    captured before any close, so closing during iteration is safe.
herdr pane list --workspace "$wsid" \
  | jq -r --arg t "$tabid" '.result.panes[] | select(.tab_id==$t) | .pane_id' \
  | while read -r p; do
      [[ -n "$p" && "$p" != "$anchor" ]] && herdr pane close "$p" || true
    done

# 3. Right split: anchor keeps 70%, new right pane = 30%.
right="$(herdr pane split "$anchor" --direction right --ratio 0.70 --no-focus | jq -r '.result.pane.pane_id')"

# 4. Down split of the right pane: top (bash) keeps 40%, new bottom (broot) = 60%.
bottom="$(herdr pane split "$right" --direction down --ratio 0.40 --no-focus | jq -r '.result.pane.pane_id')"

# 5. Launch broot in the bottom-right pane.
herdr pane run "$bottom" broot >/dev/null

# 6. Label the panes.
herdr pane rename "$anchor" agent >/dev/null
herdr pane rename "$right"  bash  >/dev/null
herdr pane rename "$bottom" files >/dev/null

# 7. Focus the agent (left) pane (the --no-focus splits already keep it focused;
#    this makes the end state explicit).
herdr pane focus --direction left --pane "$bottom" >/dev/null 2>&1 || true

echo "dev: layout ready (agent | bash / files)"
```

- [ ] **Step 4: Make it executable and run the test to verify it passes**

Run:
```bash
chmod +x bin/dev
bash tests/dev_test.sh
```
Expected: every line prints `PASS:` and the script exits 0. The reported `~70%` and `~60%` values should land near 70 and 60. Then confirm no leftover workspace: `herdr workspace list` shows only the user's real workspace(s), no `devtest`.

- [ ] **Step 5: Document `dev` in README.md**

Add this section to `README.md` immediately after the existing `## Install` section:

```markdown
## Layout preset

Inside herdr, run:

    dev

Collapses the current tab to a single pane and builds the preset:

    +----------------+--------+
    |                |  bash  |   top-right 40%
    |  agent  (70%)  +--------+
    |                |  broot |   bottom-right 60%
    +----------------+--------+
       left 70%        right 30%

broot launches automatically in the bottom-right. Re-run `dev` any time to reset
the layout. Launch your AI agent (e.g. `claude`) yourself in the left pane — the
preset shapes the layout only, it is agent-agnostic.
```

- [ ] **Step 6: Commit**

```bash
git add bin/dev tests/dev_test.sh README.md
git commit -m "feat: add bin/dev herdr layout preset (70/30 . 40/60) with live test"
```

---

### Task 2: Live visual verification in the user's real herdr session

`bin/dev` was proven correct by the automated geometry test in Task 1. Task 2 is the human confirming the preset looks and behaves right in their actual attached herdr — the one part a script cannot check.

**Files:** none (verification only).

**Interfaces:**
- Consumes: `bin/dev` from Task 1, on `PATH` via `dotfiles/bin` (installed in Phase 1).

- [ ] **Step 1: Confirm `dev` is on PATH**

Run (interactive shell): `command -v dev`
Expected: `/home/maxto/projects/personal/dotfiles/bin/dev`. (If empty, open a fresh shell so `shell/bashrc` is sourced.)

- [ ] **Step 2: Build the preset in a fresh herdr tab**

In herdr, open a new tab (single pane), then run: `dev`
Expected: the tab becomes three panes — a wide left pane, and a right column split into a smaller top and a larger bottom running broot. The command prints `dev: layout ready (agent | bash / files)`.

- [ ] **Step 3: Human visual check (the part the test cannot do)**

Confirm by eye:
- Left pane ≈ 70% width, a plain shell (this is where you'll launch `claude`).
- Top-right ≈ 40% of the right column, a plain bash shell.
- Bottom-right ≈ 60% of the right column, running **broot**.
- Focus is on the left (agent) pane after `dev` finishes.

- [ ] **Step 4: Confirm idempotent reset**

From the left pane, run `dev` again.
Expected: the tab collapses back to the same clean three-pane preset (no extra panes accumulate, broot is running bottom-right again).

- [ ] **Step 5: Record the outcome**

No code change. If Steps 2–4 all pass, Phase 2 is done. If anything looks off (wrong proportions, broot not launching, focus wrong), report exactly what differed — the automated test in Task 1 should be extended to cover the gap before re-fixing `bin/dev`.

---

## Self-Review

**Spec coverage:**
- `bin/dev` builds the 70/30 · 40/60 preset via the verified API sequence → Task 1 Step 3.
- Idempotent against current tab (collapse then rebuild) → Task 1 Step 3 (step 2 of the script) + Task 2 Step 4.
- broot auto-launches bottom-right; left/top-right stay shells; agent-agnostic → Task 1 Step 3 (steps 5) + README.
- Verified ratio semantics (0.70 / 0.40) → Global Constraints + Task 1 Step 3.
- `jq`/`herdr` dependency guard → Task 1 Step 3 (top of script).
- Live verification (geometry + broot + focus) → Task 1 test + Task 2 visual check.
- Out of scope (Phase 3): theming/colors, `docs/winterm.md`; public GitHub push.

**Placeholder scan:** No TBD/TODO; `bin/dev`, the test, and the README block are complete and literal. `PANE_ID` is a documented optional argument, not a placeholder.

**Type/name consistency:** `anchor`/`right`/`bottom` pane variables and the JSON paths in the script match those asserted in the test and listed in Global Constraints. The test builds with an explicit anchor argument, exactly the code path `bin/dev` exposes.
