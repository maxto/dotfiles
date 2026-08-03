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
- `bin/` — `wsl-ubuntu-setup` (symlink installer)

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
now on you can run `wsl-ubuntu-setup` from any directory by name.

## Keeping tools updated

All the tools installed in step 2 come from Homebrew, so one command updates
them:

```bash
brew update && brew upgrade && brew cleanup
```

`brew outdated` previews what would change. After upgrading **herdr** restart
its persistent server so the running session picks up the new binary
(`herdr` runs a background server — kill it and relaunch, or reboot the WSL
session). `oh-my-posh` can also self-update in place with `oh-my-posh upgrade`.

## herdr sessions

`herdr` on its own opens the default persistent session. To keep a project's
panes separate from everything else, name the session after it:

```bash
herdr --session dotfiles    # creates it if missing, attaches if it already exists
```

Detaching (`prefix+q`, prefix being `ctrl+b`) leaves the session running: panes,
shells, and agents keep working inside the herdr server, and the same command
brings you back. Manage them with:

```bash
herdr session list             # every session and whether it is running
herdr session attach <name>    # reattach from a plain shell
herdr session stop <name>      # stop a running session
herdr session delete <name>    # remove a stopped session
```

Inside a session the prefix is `ctrl+b`: `prefix+v` splits vertically,
`prefix+minus` horizontally, `prefix+shift+n` opens a new workspace and
`prefix+q` detaches. For a file tree in a pane, run `br` (broot).

## Scope

The repo manages the **WSL2 side** (configs + scripts). The Windows side —
Windows Terminal, PowerShell 7, Hack Nerd Font, Terminal-Icons — is documented
but applied by hand; see
[`docs/win-term-setup.md`](docs/win-term-setup.md).
