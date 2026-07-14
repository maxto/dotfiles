# WSL2 Ubuntu setup

**WSL2-side, tracked by this repo.** These tools live inside your Ubuntu WSL2
distro. This doc installs the tools; `bin/wsl-ubuntu-setup` then symlinks their
configs from this repo into place (see the README). Contrast with
[`win-term-setup.md`](win-term-setup.md), which covers the Windows side (manual,
documented only).

Run everything inside the **Ubuntu (WSL2)** shell.

---

## 1. Homebrew

Homebrew provides every tool below from one place — install it first.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Put it on `PATH` for this and future shells:

```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

Verify:

```bash
brew --version    # expect 6.x
```

## 2. Tools

Install all of them in one shot:

```bash
brew install herdr broot eza micro jq oh-my-posh
```

What each is and why it is here:

| Tool | Role in this environment |
|---|---|
| **herdr** | terminal multiplexer hosting the `agent-deck` layout (agent / bash / broot panes) |
| **broot** | file-tree navigator (bottom-right pane of `agent-deck`) |
| **micro** | terminal text editor (repo ships its `settings.json` + `bindings.json`) |
| **eza** | modern `ls`; drives the `ls` / `ll` / `la` / `tree` aliases and the color theme |
| **jq** | JSON processor; required by `bin/agent-deck` |
| **oh-my-posh** | prompt theme engine (`probua.minimal`) for the bash prompt |

The oh-my-posh prompt also needs a **Nerd Font**, but that is a terminal setting
on the Windows side — see [`win-term-setup.md`](win-term-setup.md) §3. Nothing to
install inside WSL2 for the font.

## 3. Update

```bash
brew update && brew upgrade
```

## 4. Apply the repo configs

Clone the repo (if you have not already) and run the installer to symlink the
configs and wire the prompt and aliases into your shell:

```bash
git clone https://github.com/maxto/dotfiles.git ~/projects/personal/dotfiles
cd ~/projects/personal/dotfiles
bin/wsl-ubuntu-setup
```

It is idempotent and non-destructive (existing files are backed up to
`<name>.bak`), so re-run it any time. See the README for exactly what it links.

The installer only wires the files into place — `~/.bashrc` reads them at shell
startup, so nothing changes in the shell you ran it in. Open a **new terminal**
(or reload the current one) for the prompt and eza aliases/colors to take effect:

```bash
exec bash    # or: source ~/.bashrc, or simply open a new terminal
```

## 5. Verification

```bash
for t in brew herdr broot eza micro jq oh-my-posh; do command -v "$t"; done
herdr --version; broot --version; eza --version | head -1
micro --version; jq --version; oh-my-posh --version
```

Reference (known-good versions at time of writing):

```text
Homebrew    6.0.9
herdr       0.7.3
broot       1.57.0
eza         0.23.4
micro       2.0.15
jq          1.8.2
oh-my-posh  29.24.0
```
```

Paths:

```text
Homebrew prefix:  /home/linuxbrew/.linuxbrew
Repo:             ~/projects/personal/dotfiles
Shell config:     ~/.bashrc  ->  sources shell/bashrc from the repo
```
