# dotfiles Phase 1 (Blocks + Installer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture the live herdr/broot/micro/shell configs into the repo and provide an idempotent, non-destructive `bin/setup` that symlinks them back into place.

**Architecture:** One directory per tool "block" holding the real config file. `bin/setup` is a data-driven bash script: it walks a list of `target|source` pairs, backs up any existing real file to `<name>.bak`, then symlinks the live location to the repo file. It also appends a single `source <repo>/shell/bashrc` line to `~/.bashrc` (which puts `<repo>/bin` on `PATH`). The installer reads `$HOME`/`$XDG_CONFIG_HOME`, so it can be exercised against a sandbox HOME in tests without touching the real system.

**Tech Stack:** bash, POSIX coreutils, git. Tests are plain bash assertion scripts (no bats dependency).

## Global Constraints

- Platform: WSL2 Ubuntu; Linux filesystem only. Do not write to `/mnt/c`.
- Language: all code, config, filenames, comments, docs in **English**.
- Naming: short names, no unnecessary complexity.
- Installer must be **idempotent** (re-running changes nothing) and **non-destructive** (never delete a config; back existing real files up to `<name>.bak`).
- Installer name is `bin/setup` (not `install`/`link`) to avoid shadowing coreutils commands once `bin` is on `PATH`.
- `.gitignore` excludes herdr runtime + backups: `*.sock`, `*.log`, `session.json`, `*.bak`.
- Do NOT delete broot's existing `conf.hjson`; only track `conf.toml`.

---

### Task 1: Scaffold repo, capture live configs, shell entry, .gitignore, README

**Files:**
- Create: `herdr/config.toml` (copied from live)
- Create: `broot/conf.toml` (copied from live)
- Create: `micro/settings.json` (copied from live)
- Create: `micro/bindings.json` (copied from live)
- Create: `shell/bashrc`
- Create: `.gitignore`
- Create: `README.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: repo config files at the paths above that `bin/setup` (Task 2) links to; `shell/bashrc` which the `~/.bashrc` source line loads.

- [ ] **Step 1: Create directories and capture the live configs**

```bash
cd /home/maxto/projects/personal/dotfiles
mkdir -p herdr broot micro shell bin
cp ~/.config/herdr/config.toml   herdr/config.toml
cp ~/.config/broot/conf.toml     broot/conf.toml
cp ~/.config/micro/settings.json micro/settings.json
cp ~/.config/micro/bindings.json micro/bindings.json
```

- [ ] **Step 2: Verify the captured broot verb is intact**

Run: `cat broot/conf.toml`
Expected output (the micro `edit` verb — proves broot is honoring conf.toml):

```toml
[[verbs]]
invocation = "edit"
key = "ctrl-e"
execution = "micro {file}"
leave_broot = false
```

- [ ] **Step 3: Write `shell/bashrc`**

This file is sourced from `~/.bashrc`. It resolves the repo root from its own
location and prepends `bin/` to `PATH` so `dev` (Phase 2) and `setup` run as
bare commands.

```bash
# dotfiles shell config — sourced from ~/.bashrc
# Resolve the repo root relative to this file (shell/ -> repo root).
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$DOTFILES_DIR/bin:$PATH"
```

- [ ] **Step 4: Write `.gitignore`**

```gitignore
# herdr runtime artifacts
*.sock
*.log
session.json

# installer backups
*.bak
```

- [ ] **Step 5: Write `README.md`**

```markdown
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

## Conventions

Code, config, filenames, comments and docs are in English. Short names, no
unnecessary complexity.

## Scope

WSL2 side only. Windows Terminal appearance (font, colors, title) is configured
by hand in the Windows-side `settings.json` and is not managed here.
```

- [ ] **Step 6: Commit**

```bash
cd /home/maxto/projects/personal/dotfiles
git add herdr broot micro shell .gitignore README.md
git commit -m "feat: capture herdr/broot/micro/shell configs and repo skeleton"
```

---

### Task 2: `bin/setup` symlink installer (TDD, sandboxed)

**Files:**
- Create: `tests/setup_test.sh`
- Create: `bin/setup`

**Interfaces:**
- Consumes: repo config files from Task 1 (`herdr/config.toml`, `broot/conf.toml`, `micro/settings.json`, `micro/bindings.json`), `shell/bashrc`.
- Produces: `bin/setup`, an executable that reads `$HOME` and `${XDG_CONFIG_HOME:-$HOME/.config}`, creates the symlinks, and ensures one `source <repo>/shell/bashrc` line in `~/.bashrc`.

- [ ] **Step 1: Write the failing test**

Create `tests/setup_test.sh`. It runs `bin/setup` against a throwaway `HOME`
so the real system is never touched, and asserts symlink creation, backup of a
pre-existing real file, the bashrc source line, and idempotency on a second run.

```bash
#!/usr/bin/env bash
# Exercise bin/setup in a sandbox HOME. Does not affect the real system.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
export XDG_CONFIG_HOME="$TMP/.config"

# A pre-existing REAL herdr config that must be backed up, and a base bashrc.
mkdir -p "$XDG_CONFIG_HOME/herdr"
echo "OLD" > "$XDG_CONFIG_HOME/herdr/config.toml"
echo "# base bashrc" > "$HOME/.bashrc"

bash "$REPO/bin/setup" >/dev/null

check "herdr config is a symlink into the repo" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" && "$(readlink -f "$XDG_CONFIG_HOME/herdr/config.toml")" == "$REPO/herdr/config.toml" ]]'

check "old real herdr config backed up with original content" \
  '[[ -f "$XDG_CONFIG_HOME/herdr/config.toml.bak" && "$(cat "$XDG_CONFIG_HOME/herdr/config.toml.bak")" == "OLD" ]]'

check "micro bindings linked when target was absent" \
  '[[ -L "$XDG_CONFIG_HOME/micro/bindings.json" ]]'

check "bashrc has the source line" \
  'grep -qxF "source $REPO/shell/bashrc" "$HOME/.bashrc"'

# Second run: must not duplicate the source line, must not re-backup.
bash "$REPO/bin/setup" >/dev/null

check "source line present exactly once after rerun" \
  '[[ "$(grep -cxF "source $REPO/shell/bashrc" "$HOME/.bashrc")" -eq 1 ]]'

check "herdr config still a symlink after rerun" \
  '[[ -L "$XDG_CONFIG_HOME/herdr/config.toml" ]]'

check "no double backup created on rerun" \
  '[[ ! -e "$XDG_CONFIG_HOME/herdr/config.toml.bak.bak" ]]'

exit $fail
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/setup_test.sh`
Expected: fails — `bin/setup` does not exist yet (bash reports "No such file or directory" and checks FAIL).

- [ ] **Step 3: Write `bin/setup`**

```bash
#!/usr/bin/env bash
# Symlink live config locations to this repo. Idempotent and non-destructive:
# existing real files are backed up to <name>.bak before being replaced.
set -euo pipefail

# Resolve repo root from this script's own location (bin/ -> repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# target (live location) | source (path inside the repo)
links=(
  "$CONFIG/herdr/config.toml|herdr/config.toml"
  "$CONFIG/broot/conf.toml|broot/conf.toml"
  "$CONFIG/micro/settings.json|micro/settings.json"
  "$CONFIG/micro/bindings.json|micro/bindings.json"
)

link_one() {
  local target="$1" src="$REPO/$2"
  mkdir -p "$(dirname "$target")"
  # Already the correct symlink: nothing to do.
  if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$src")" ]]; then
    echo "ok     $target"
    return
  fi
  # Existing real file or a stale link: preserve it before replacing.
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$target.bak"
    echo "backup $target -> $target.bak"
  fi
  ln -s "$src" "$target"
  echo "link   $target -> $src"
}

for pair in "${links[@]}"; do
  link_one "${pair%%|*}" "${pair#*|}"
done

# Ensure ~/.bashrc sources the repo shell config exactly once.
BASHRC="$HOME/.bashrc"
SOURCE_LINE="source $REPO/shell/bashrc"
if ! grep -qxF "$SOURCE_LINE" "$BASHRC" 2>/dev/null; then
  printf '\n# dotfiles\n%s\n' "$SOURCE_LINE" >> "$BASHRC"
  echo "bashrc added source line"
else
  echo "bashrc already sources repo"
fi

echo "done"
```

- [ ] **Step 4: Make it executable and run the test to verify it passes**

Run:
```bash
chmod +x bin/setup
bash tests/setup_test.sh
```
Expected: every line prints `PASS:` and the script exits 0.

- [ ] **Step 5: Commit**

```bash
cd /home/maxto/projects/personal/dotfiles
git add bin/setup tests/setup_test.sh
git commit -m "feat: add idempotent non-destructive bin/setup symlink installer"
```

---

### Task 3: Apply to the live system and verify

This task runs `bin/setup` for real, replacing the live config files with
symlinks into the repo, and confirms every tool still works. It changes the real
`~/.config` and `~/.bashrc`, so it gets its own review gate.

**Files:**
- Modify (live, not in repo): `~/.config/*` targets become symlinks; `~/.bashrc` gains one source line.

**Interfaces:**
- Consumes: `bin/setup` (Task 2), repo configs (Task 1).
- Produces: a verified live environment; no new repo files (backups are gitignored).

- [ ] **Step 1: Run the installer against the live system**

Run: `bin/setup`
Expected: `link`/`backup`/`ok` lines for the four configs and a bashrc line, ending in `done`. First run should back up the live herdr/broot/micro files (they are currently real files) to `<name>.bak`.

- [ ] **Step 2: Verify every target is a symlink into the repo**

Run: `ls -l ~/.config/herdr/config.toml ~/.config/broot/conf.toml ~/.config/micro/settings.json ~/.config/micro/bindings.json`
Expected: each line shows `-> /home/maxto/projects/personal/dotfiles/<block>/<file>`.

- [ ] **Step 3: Confirm the backups match the originals**

Run: `diff ~/.config/broot/conf.toml.bak broot/conf.toml`
Expected: no output (the backed-up original is identical to the captured repo copy — capture in Task 1 was faithful).

- [ ] **Step 4: Verify `~/.bashrc` sources the repo exactly once**

Run: `grep -cxF "source /home/maxto/projects/personal/dotfiles/shell/bashrc" ~/.bashrc`
Expected: `1`.

- [ ] **Step 5: Verify the tools start from the linked configs**

Run:
```bash
herdr server reload-config    # reads ~/.config/herdr/config.toml (now a symlink)
micro -version                # micro is present and runs
broot --version               # broot is present and runs
```
Expected: `reload-config` succeeds without a parse error; `micro`/`broot` print versions. (herdr is a persistent server — `reload-config` re-reads the linked file, proving the symlink resolves.)

- [ ] **Step 6: Verify broot honors `conf.toml` despite `conf.hjson` coexisting**

broot still has an untracked `~/.config/broot/conf.hjson` alongside the linked
`conf.toml`. Confirm the `edit`/`ctrl-e` verb from `conf.toml` is active.

Run: `broot --print-shell-function bash >/dev/null && echo "broot ok"`
Then, interactively (manual check): open `broot`, press `ctrl-e` on a file, and confirm it opens in **micro**, not nano.
Expected: `ctrl-e` opens micro. If it does not, broot is reading `conf.hjson` first — record this and decide with the user whether to also track/rename `conf.hjson` (do **not** delete it automatically).

- [ ] **Step 7: Load the shell entry in a fresh shell and confirm PATH**

Run: `bash -lc 'source ~/.bashrc; command -v dev; echo "$PATH" | tr ":" "\n" | grep dotfiles/bin'`
Expected: the `dotfiles/bin` entry appears on `PATH`. (`dev` itself is Phase 2, so `command -v dev` may be empty — the PATH entry is what matters here.)

- [ ] **Step 8: Commit any drift captured during verification**

If verification revealed a config that should be updated in the repo (e.g. a
newer live herdr config), edit the repo file and commit. Otherwise, nothing to
commit (backups are gitignored).

```bash
cd /home/maxto/projects/personal/dotfiles
git status            # expect clean, or stage intentional config updates
```

---

## Self-Review

**Spec coverage:**
- Repo structure (herdr/broot/micro/shell/bin/docs/README) → Task 1 (docs/winterm.md is Phase 3, out of Phase 1 scope).
- Apply model / symlinks / non-destructive backup / bashrc source line / PATH → Task 2 + Task 3.
- Naming `bin/setup` (collision avoidance) → Global Constraints + Task 2.
- broot `conf.hjson`/`conf.toml` coexistence, no auto-delete → Global Constraints + Task 3 Step 6.
- `.gitignore` (`*.sock`,`*.log`,`session.json`,`*.bak`) → Task 1 Step 4.
- micro `bindings.json` tracked in addition to `settings.json` → Task 1 + Task 2 links.
- Phase 1 verification approach (symlink check, tools start, bashrc once) → Task 3.
- Out of Phase 1: `bin/dev` (Phase 2), theming and `docs/winterm.md` (Phase 3), `git init`/GitHub push (repo already `git init`ed; remote push handled separately when the user is ready).

**Placeholder scan:** No TBD/TODO; all scripts and test code are complete and literal.

**Type/name consistency:** `bin/setup`, `shell/bashrc`, `SOURCE_LINE`, `$XDG_CONFIG_HOME` used consistently across Tasks 2 and 3; the four `target|source` pairs match the repo files created in Task 1.
