# desk Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `bin/desk` so it launches herdr with a fixed 3-pane layout from a plain WSL2 shell, all panes anchored to `$PWD`.

**Architecture:** `desk` is a single bash script. It ensures the herdr server is running (starting it headless if needed), creates a new workspace anchored to `$PWD` over the herdr socket API, builds a 3-pane layout in it (agent | bash / files), focuses it, and `exec herdr` to attach the terminal. A guard skips the final attach when already inside herdr.

**Tech Stack:** bash, herdr CLI (socket API), jq, broot (`br`), shellcheck for linting.

## Global Constraints

- All code/comments/files in English (chat may be Italian).
- Script lives at `bin/desk`, keeps `#!/usr/bin/env bash` and `set -euo pipefail`.
- Preconditions checked with the existing message style: `desk: <tool> is required`.
- Split ratios: right split `--ratio 0.60`, down split `--ratio 0.40`.
- All three panes created with `--cwd "$dir"` where `dir="$PWD"`.
- Pane names: `agent` (left), `bash` (right-top), `files` (right-bottom).
- Files pane runs `br "$dir"`.
- herdr socket returns JSON; parse with `jq -r`.

---

### Task 1: Rewrite `bin/desk` as a from-outside launcher

**Files:**
- Modify (full rewrite): `bin/desk`

**Interfaces:**
- Consumes: herdr CLI subcommands `status server`, `server`, `workspace create`, `pane split`, `pane run`, `pane rename`, `workspace focus`, `pane focus`.
- Produces: an executable `desk` command on PATH (already symlinked/shipped via the repo's bin) taking no arguments.

Reference JSON shapes (verified 2026-07-14):
- `herdr workspace create --cwd PATH --label TEXT --no-focus` →
  `.result.root_pane.pane_id` (the agent anchor), `.result.workspace.workspace_id`.
- `herdr pane split <pane> --direction <dir> --ratio <r> --cwd PATH --no-focus` →
  `.result.pane.pane_id`.

- [ ] **Step 1: Write the new `bin/desk`**

Replace the entire contents of `bin/desk` with:

```bash
#!/usr/bin/env bash
# Launch herdr with the "desk" 3-pane layout, anchored to the current dir.
#
# Run from a plain WSL2 shell inside a project folder:
#   left 60% = agent (plain shell) | right 40%: top 40% = bash, bottom 60% = files (br)
# All three panes open in $PWD, so agent, bash, and the broot tree see only
# that folder. Creates a fresh herdr workspace and attaches the terminal to it.
# Usage: desk   (no arguments)
set -euo pipefail

command -v jq    >/dev/null || { echo "desk: jq is required"    >&2; exit 1; }
command -v herdr >/dev/null || { echo "desk: herdr is required" >&2; exit 1; }

# 1. Ensure the herdr server is running. Normally it is (persistent session);
#    on a cold boot start it headless and wait for the socket to answer.
if ! herdr status server >/dev/null 2>&1; then
  herdr server >/dev/null 2>&1 &
  for _ in $(seq 1 50); do
    herdr status server >/dev/null 2>&1 && break
    sleep 0.1
  done
  herdr status server >/dev/null 2>&1 || { echo "desk: herdr server did not start" >&2; exit 1; }
fi

# 2. Anchor dir: all panes open here.
dir="$PWD"
label="$(basename "$dir")"

# 3. Create a fresh workspace anchored to $dir. Its single root pane is the
#    left/agent pane.
create="$(herdr workspace create --cwd "$dir" --label "$label" --no-focus)"
anchor="$(echo "$create" | jq -r '.result.root_pane.pane_id')"
wsid="$(echo "$create" | jq -r '.result.workspace.workspace_id')"

# 4. Right split: agent keeps 60%, new right pane = 40% (bash).
right="$(herdr pane split "$anchor" --direction right --ratio 0.60 --cwd "$dir" --no-focus | jq -r '.result.pane.pane_id')"

# 5. Down split of the right pane: bash keeps 40%, new bottom = 60% (files).
bottom="$(herdr pane split "$right" --direction down --ratio 0.40 --cwd "$dir" --no-focus | jq -r '.result.pane.pane_id')"

# 6. Launch broot (via the `br` launcher) in the bottom-right pane, rooted at $dir.
herdr pane run "$bottom" "br \"$dir\"" >/dev/null

# 7. Label the panes.
herdr pane rename "$anchor" agent >/dev/null
herdr pane rename "$right"  bash  >/dev/null
herdr pane rename "$bottom" files >/dev/null

# 8. Focus the new workspace and the agent pane.
herdr workspace focus "$wsid" >/dev/null 2>&1 || true
herdr pane focus "$anchor"    >/dev/null 2>&1 || true

echo "desk: layout ready (agent | bash / files) in $label"

# 9. Attach: turn this terminal into the herdr TUI on the new workspace.
#    Skip when already inside herdr (guard) — the terminal is already attached.
if [[ "${HERDR_ENV:-}" != "1" ]]; then
  exec herdr
fi
```

- [ ] **Step 2: Verify syntax and lint**

Run: `bash -n bin/desk && shellcheck bin/desk`
Expected: no output from `bash -n`; shellcheck exits 0 (no warnings). If shellcheck flags `SC2086` on unquoted vars, fix by quoting; the script above already quotes all expansions.

- [ ] **Step 3: Confirm executable bit**

Run: `test -x bin/desk && echo executable || chmod +x bin/desk`
Expected: prints `executable` (the file was already tracked executable). If not, `chmod +x` sets it.

- [ ] **Step 4: End-to-end manual validation**

This step is manual because `desk` ends in `exec herdr` (an interactive TUI) and cannot be asserted headlessly. Validate the layout-build portion over the socket WITHOUT attaching, by temporarily running the body with the `exec herdr` guarded off:

Run:
```bash
cd /tmp
HERDR_ENV=1 bash /home/maxto/projects/personal/dotfiles/bin/desk
```
Expected: prints `desk: layout ready (agent | bash / files) in tmp` and does NOT attach (guard skips `exec`). Then inspect:
```bash
herdr workspace list | jq -r '.result.workspaces[] | select(.label=="tmp") | .workspace_id'
```
Expected: prints a workspace id. Then verify it has 3 panes named agent/bash/files:
```bash
ws=$(herdr workspace list | jq -r '.result.workspaces[] | select(.label=="tmp") | .workspace_id' | head -1)
herdr pane list --workspace "$ws" | jq -r '.result.panes[] | .title // .name // .pane_id'
```
Expected: three panes; the renames (agent, bash, files) are visible in herdr.

Then clean up the probe workspace:
```bash
herdr workspace close "$ws" >/dev/null && echo "probe closed"
```
Expected: `probe closed`.

- [ ] **Step 5: Commit**

```bash
git add bin/desk
git commit -m "feat: desk launches herdr layout from a plain shell

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** Precondition checks (Step 1), ensure-server cold boot (Step 1 §1), anchor `$PWD` + label basename (§2), workspace create capturing root pane (§3), 60/40 and 40/60 splits with `--cwd` (§4–5), `br "$dir"` in files (§6), pane renames (§7), focus workspace + agent (§8), `exec herdr` attach with `HERDR_ENV` guard (§9). All spec sections mapped.
- **Removed items from old script** (pane-current anchor, `[PANE_ID]` arg, tab-collapse loop) are simply absent in the rewrite — nothing to do.
- **Placeholder scan:** none.
- **Type consistency:** `root_pane.pane_id` / `workspace.workspace_id` / `pane.pane_id` match the verified JSON shapes in the spec.
