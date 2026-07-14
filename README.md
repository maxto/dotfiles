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
- `bin/` — `wsl-ubuntu-setup` (symlink installer), `desk` (herdr layout preset)

## Setup (from scratch)

Full rebuild on a new machine. Do the steps in order.

### 1. Windows side (manual)

Windows Terminal, PowerShell 7, Hack Nerd Font, and the Windows Terminal
`settings.json` live on Windows, not in this repo. Follow
[`docs/win-term-setup.md`](docs/win-term-setup.md) by hand.

### 2. WSL2 tools

Inside the Ubuntu (WSL2) shell, install Homebrew and the tools. Per-tool details
and a known-good version table are in
[`docs/wsl-ubuntu-setup.md`](docs/wsl-ubuntu-setup.md); the short version:

```bash
# Homebrew (prerequisite), then put it on PATH
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# The tools
brew install herdr broot eza micro jq oh-my-posh
```

### 3. Clone this repo

The installer and configs live in the repo, so you must clone it. Pick a
**permanent** location — step 4 writes this path into `~/.bashrc`, so moving the
repo later breaks that line.

```bash
git clone https://github.com/maxto/dotfiles.git ~/projects/personal/dotfiles
cd ~/projects/personal/dotfiles
```

### 4. Wire the configs

```bash
bin/wsl-ubuntu-setup
```

Symlinks `~/.config/*` into this repo and adds a single `source .../shell/bashrc`
line to `~/.bashrc`. Idempotent and non-destructive (existing files are backed up
to `<name>.bak`), so you can re-run it any time. The script finds the repo from
its own location, so you can also run it by full path from anywhere
(`~/projects/personal/dotfiles/bin/wsl-ubuntu-setup`).

### 5. Reload the shell

```bash
exec bash        # or: source ~/.bashrc, or just open a new terminal
```

`~/.bashrc` is only read at shell startup, so nothing changes in the shell you
ran step 4 in. After the reload the Oh My Posh prompt and the eza aliases/colors
(white folders) are active, and `.../dotfiles/bin` is on your `PATH` — so from
now on you can run `wsl-ubuntu-setup` (and `desk`) from any directory by name.

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

## Scope

The repo manages the **WSL2 side** (configs + scripts). The Windows side —
Windows Terminal, PowerShell 7, Hack Nerd Font, Terminal-Icons — is documented
but applied by hand; see
[`docs/win-term-setup.md`](docs/win-term-setup.md).
