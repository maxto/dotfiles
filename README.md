# dotfiles

Personal WSL2 (Ubuntu on Windows 11) human-AI dev environment: Windows Terminal
→ WSL2 → herdr (multiplexer) with broot (file tree), micro (editor), and shell
panes for AI agents.

## Layout

One directory per tool block:

- `herdr/` — herdr `config.toml`
- `broot/` — broot `conf.toml`
- `micro/` — micro `settings.json`, `bindings.json`
- `oh-my-posh/` — `probua.minimal.omp.json` prompt theme
- `eza/` — `theme.yml` (colors for the `ls`/`ll`/`la`/`tree` aliases)
- `shell/` — `bashrc`, sourced from `~/.bashrc` (prompt init + eza aliases)
- `bin/` — `setup` (symlink installer), `desk` (herdr layout preset)

## Install

```bash
bin/setup
```

Creates symlinks from `~/.config/*` into this repo and adds a single
`source .../shell/bashrc` line to `~/.bashrc`. Idempotent and non-destructive:
existing real files are backed up to `<name>.bak`.

## Layout preset

Inside herdr, run:

    desk

Collapses the current tab to a single pane and builds the preset:

    +----------------+--------+
    |                |  bash  |   top-right 40%
    |  agent  (70%)  +--------+
    |                |  broot |   bottom-right 60%
    +----------------+--------+
       left 70%        right 30%

broot launches automatically in the bottom-right. Re-run `desk` any time to reset
the layout. Launch your AI agent (e.g. `claude`) yourself in the left pane — the
preset shapes the layout only, it is agent-agnostic.

## Conventions

Code, config, filenames, comments and docs are in English. Short names, no
unnecessary complexity.

## Windows Terminal + PowerShell 7

The Windows side (terminal appearance, font, PowerShell 7 prompt) lives on
Windows, not in this repo, so it is set up by hand. See
[`docs/win-term-setup.md`](docs/win-term-setup.md) for step-by-step instructions
(PowerShell 7, Hack Nerd Font, the curated Windows Terminal `settings.json`, and
Oh My Posh + Terminal-Icons).

## Scope

The repo manages the **WSL2 side** (configs + scripts). Windows Terminal and the
PowerShell 7 prompt are documented but applied by hand — see above.
