# dotfiles

Personal WSL2 (Ubuntu on Windows 11) human-AI dev environment: Windows Terminal
→ WSL2 → herdr (multiplexer) with broot (file tree), micro (editor), and shell
panes for AI agents.

## Layout

One directory per tool block:

- `herdr/` — herdr `config.toml`
- `broot/` — broot `conf.toml`
- `micro/` — micro `settings.json`, `bindings.json`
- `shell/` — `bashrc`, sourced from `~/.bashrc`
- `bin/` — `setup` (symlink installer), `dev` (herdr layout preset)

## Install

```bash
bin/setup
```

Creates symlinks from `~/.config/*` into this repo and adds a single
`source .../shell/bashrc` line to `~/.bashrc`. Idempotent and non-destructive:
existing real files are backed up to `<name>.bak`.

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

## Conventions

Code, config, filenames, comments and docs are in English. Short names, no
unnecessary complexity.

## Scope

WSL2 side only. Windows Terminal appearance (font, colors, title) is configured
by hand in the Windows-side `settings.json` and is not managed here.
