# dotfiles — WSL2 human-AI dev environment

**Date:** 2026-07-08
**Status:** Approved (design)

## Purpose

A personal repo that integrates a small set of terminal tools into a simple,
VSCode-like human-AI agentic development environment for **Windows 11 + WSL2
Ubuntu**. The goal is a reproducible setup that opens into a fixed working
layout — an AI agent pane beside a shell and a file tree — without unnecessary
complexity.

## Real setup (target environment)

- **Host:** Windows Terminal
- **Boot shell:** WSL2 Ubuntu
- **Multiplexer:** herdr (`0.7.2`, installed via Homebrew/linuxbrew)
- **File tree:** broot
- **Terminal editor:** micro
- **Workflow:** terminal panes for shell and AI agents

herdr, broot, micro and the Ubuntu-on-open Windows Terminal profile are already
installed. This repo captures and manages their configuration, not their
installation.

## Conventions

- Code, config, filenames, folder names, comments, and technical docs are in
  **English**.
- Human-AI chat may be in the human's preferred language.
- Simple structure, short names, no unnecessary complexity.

## Scope

**In scope (WSL2 filesystem only):** herdr, broot, micro, the shell (bash), a
symlink installer, and the layout preset script.

**Out of scope:** Windows Terminal appearance (font, colors, title) lives in the
Windows-side `settings.json`, not WSL2. Those are manual choices made by hand at
the end of the project. The repo keeps only a reference note of what was chosen
(`docs/win-term-setup.md`); it does not apply anything on the Windows side.

## Repo structure

```
dotfiles/
  herdr/config.toml          # multiplexer config
  broot/conf.toml            # file tree config
  micro/settings.json        # editor config
  micro/bindings.json        # editor keybindings
  shell/bashrc               # sourced from ~/.bashrc; puts bin/ on PATH
  bin/
    setup                    # create symlinks (idempotent, backs up existing)
    dev                      # build the herdr layout preset
  docs/
    win-term-setup.md          # manual Windows Terminal + PowerShell 7 setup guide
  README.md
```

One directory per tool "block". Exact config filenames are confirmed against the
live install during Phase 1 (e.g. broot uses `conf.toml`; micro uses
`settings.json`).

## Apply model — symlinks

`bin/setup` creates symlinks from the live config locations into the repo, so
that editing a repo file *is* the live change and git tracks it immediately.

- `~/.config/herdr/config.toml`    → `dotfiles/herdr/config.toml`
- `~/.config/broot/conf.toml`      → `dotfiles/broot/conf.toml`
- `~/.config/micro/settings.json`  → `dotfiles/micro/settings.json`
- `~/.config/micro/bindings.json`  → `dotfiles/micro/bindings.json`
- `~/.bashrc` is **not** symlinked. Instead `setup` ensures a single line
  `source <repo>/shell/bashrc` is present in `~/.bashrc`, to avoid clobbering
  WSL's default `.bashrc`. `shell/bashrc` prepends `<repo>/bin` to `PATH` so
  `desk` (and future scripts) run as bare commands.

**Naming note:** the installer is `bin/setup`, not `bin/install`, because `bin`
is on `PATH` and a file named `install` (or `link`) would shadow the coreutils
commands of the same name. `setup` and `desk` have no such collision.

Requirements for `setup`:

- **Idempotent:** re-running produces the same result; it does not duplicate the
  `source` line or re-create existing correct symlinks.
- **Non-destructive:** before replacing an existing real file with a symlink, it
  moves the original aside to `<name>.bak`. It never silently deletes a config.
- Resolves the repo path relative to its own location, so it works regardless of
  where the repo is cloned.

## `bin/desk` — layout preset

herdr has **no declarative startup layout** in `config.toml`. Layout is built
imperatively through herdr's socket API (all subcommands emit JSON; parse with
`jq`) and then persisted by herdr in `session.json`. `bin/desk` builds the preset
on demand. It is **idempotent against the current tab**: it collapses the tab to a
single pane, then rebuilds — so re-running always yields the same clean preset
(this is the "reset" path).

Target layout:

```
+----------------+--------+
|                |  bash  |   right-top  40%
|   agent (70%)  +--------+
|                |  broot |   right-bottom 60%
+----------------+--------+
   left 70%        right 30%
```

**Verified ratio semantics (spike, 2026-07-09):** `--ratio` is the fraction kept
by the *original* pane; the new pane gets `1 − ratio`. Measured against a 54-col ×
23-row area: `--direction right --ratio 0.70` → original 38 / new 16; `--direction
down --ratio 0.40` → original 9 / new 14. So:

Build sequence (`PANE_ID` defaults to the currently focused pane; an explicit
pane argument is accepted so the layout can be built around a throwaway pane in
tests without stealing focus):

1. Resolve the **anchor** pane (becomes left/agent) and its tab via
   `herdr pane current` / `herdr pane get`.
2. Collapse the tab: `herdr pane close` every other pane in the same tab.
3. `herdr pane split <anchor> --direction right --ratio 0.70 --no-focus` →
   **right** column = 30%.
4. `herdr pane split <right> --direction down --ratio 0.40 --no-focus` →
   **bottom-right** = 60% (broot); top-right = 40% (bash).
5. `herdr pane run <bottom-right> broot`.
6. `herdr pane rename` the panes `agent` / `bash` / `files`.
7. Focus the left/agent pane (`herdr pane focus --direction left`).

The left and top-right panes stay plain bash shells. The user launches `claude`
(or any agent) manually in the left pane — the preset shapes layout only, it is
agent-agnostic. `bin/desk` requires `jq` and `herdr` and errors clearly if either
is missing.

## Git / GitHub

- `git init`, then a `.gitignore` excluding herdr runtime artifacts and
  installer backups: `*.sock`, `*.log`, `session.json`, `*.bak`.
- Initial commit, then create the GitHub repo named **`dotfiles`** and push.

## Phased roadmap

Built in the user's stated order. This spec covers the whole repo; Phase 1 is
planned and built first.

1. **Phase 1 — blocks (manual setup of individual pieces):** capture the current
   herdr / broot / micro / shell configs into the repo, write `bin/setup`,
   verify the symlinks resolve and the tools still start from them. Note: broot
   currently has both `conf.hjson` and `conf.toml` live; confirm broot honors
   `conf.toml` (the tracked file) given the coexistence, and do not delete
   `conf.hjson` automatically.
2. **Phase 2 — layout (functional):** write and verify `bin/desk` against a live
   herdr session; confirm the ratios produce 70/30 and 40/60 and that broot
   launches in the bottom-right.
3. **Phase 3 — aesthetics (appearance):** theme herdr (`config.toml` is already
   `gruvbox`), broot and micro colors, and the manual Windows Terminal pass
   documented in `docs/win-term-setup.md`.

## Verification approach

- **Phase 1:** after `bin/setup`, check each target is a symlink pointing into
  the repo (`ls -l`), and that herdr/broot/micro start without error reading the
  linked config. Confirm `~/.bashrc` sources the repo file exactly once.
- **Phase 2:** run `bin/desk` in a live herdr session and read back
  `herdr pane list` to confirm three panes with the expected split ratios and
  broot running in the bottom-right.
