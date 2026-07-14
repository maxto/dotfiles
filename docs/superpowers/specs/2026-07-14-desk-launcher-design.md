# desk — herdr layout launcher

**Date:** 2026-07-14
**Status:** Approved design

## Purpose

Provide a single command, `desk`, that a WSL2 user runs from a plain shell
inside a project folder. It launches herdr with a fixed 3-pane layout, all
panes anchored to that folder, and attaches the terminal to the herdr session.

The current `bin/desk` only works when already running *inside* herdr (it
relies on `herdr pane current`). Launched from a bare shell it fails. This
design replaces it with a from-outside launcher.

## Scope

- **In scope:** launch from a plain WSL2 shell (outside herdr).
- **Out of scope:** rebuilding the layout in the current tab when already inside
  herdr. A minimal guard covers accidental in-herdr invocation (see below), but
  it is not a supported second mode.

## Behavior

`desk` takes no arguments. It uses `$PWD` as the anchor directory for all panes.

The `agent` pane is left as a bare shell — `desk` does not auto-launch any agent
CLI.

### Layout

```
┌─────────────────┬───────────────┐
│                 │  bash (40h)   │
│   agent (60w)   ├───────────────┤
│                 │  files (60h)  │
│                 │  br "$dir"    │
└─────────────────┴───────────────┘
```

- Left 60% width: `agent` (bare shell).
- Right 40% width, split vertically:
  - Top 40% height: `bash` (bare shell).
  - Bottom 60% height: `files`, running `br "$dir"` (broot).

All three panes open with `--cwd "$dir"`, so the agent, the bash shell, and the
broot tree all see only that folder.

## Steps

1. **Preconditions** — verify `jq` and `herdr` are on PATH; exit with a clear
   message otherwise (unchanged from current script).
2. **Ensure server** — if the herdr server is not running (checked via
   `herdr status server`), start it headless with `herdr server` in the
   background, then poll until the API socket responds before proceeding. In the
   normal case (persistent server already running) this step is a no-op.
3. **Anchor dir** — `dir="$PWD"`.
4. **Create workspace** — `herdr workspace create --cwd "$dir"
   --label "<basename of dir>" --no-focus`. Capture `.result.root_pane.pane_id`
   as the `anchor` (the agent pane). The label is the folder's basename so
   workspaces are identifiable in the herdr UI.
5. **Build layout** in that workspace:
   - `right = herdr pane split "$anchor" --direction right --ratio 0.60 --cwd "$dir" --no-focus`
   - `bottom = herdr pane split "$right" --direction down --ratio 0.40 --cwd "$dir" --no-focus`
   - `herdr pane run "$bottom" 'br "$dir"'`
   - rename panes: `anchor`→`agent`, `right`→`bash`, `bottom`→`files`.
6. **Focus** — focus the new workspace and the agent pane.
7. **Attach** — `exec herdr` so the current terminal becomes the herdr TUI,
   landing on the new workspace with the agent pane focused.

## In-herdr guard

If `desk` is invoked with `HERDR_ENV=1` (already inside herdr), it still creates
a new workspace and builds the layout, focuses it, and then **skips** the final
`exec herdr` (the terminal is already attached). This is a two-line safety, not
a separate code path.

## Differences from current `bin/desk`

- **Removed:** `herdr pane current` anchor logic and the optional `[PANE_ID]`
  argument (only meaningful from inside herdr).
- **Removed:** the tab-collapse loop (`herdr pane close` of existing panes) —
  a freshly created workspace starts with a single pane, so there is nothing to
  collapse.
- **Added:** ensure-server step, `herdr workspace create`, `exec herdr` attach,
  and the `HERDR_ENV` guard.
- **Unchanged:** split ratios (60/40, 40/60), pane names, `br "$dir"` in the
  files pane, `jq`/`herdr` precondition checks.

## Validation notes

- `herdr workspace create --cwd PATH` works from a bare shell over the socket and
  returns `.result.root_pane.pane_id` (verified 2026-07-14 with a probe
  workspace, then closed).
- `herdr server` runs headless, enabling the cold-boot path.

## Naming

The command keeps the name `desk` for now; it may be renamed later. This design
does not depend on the name.
