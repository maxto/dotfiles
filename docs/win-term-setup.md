# Windows Terminal + PowerShell 7 setup

**Manual, Windows-side.** These tools live on Windows, not in WSL2, so this repo
only **documents** the setup — it does not apply anything to `/mnt/c`. Follow the
steps by hand on a new machine to reproduce the terminal look. The WSL2/bash
prompt (Oh My Posh, `eza`) is handled separately as tracked repo config, not here.

Run the PowerShell steps in **PowerShell 7** (`pwsh`), not Windows PowerShell 5.

---

## 1. PowerShell 7

Install:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Update later:

```powershell
winget upgrade --id Microsoft.PowerShell --source winget
```

Verify (open a new **PowerShell 7** tab):

```powershell
$PSVersionTable.PSVersion    # expect 7.x
```

## 2. Oh My Posh

Installed first because it also provides the font installer used in step 3.

```powershell
winget install --id JanDeDobbeleer.OhMyPosh --source winget
```

Close **all** Windows Terminal windows, reopen, then verify:

```powershell
oh-my-posh --version
```

If you get *"oh-my-posh is not recognized"*, the executable exists but isn't on
`PATH`. Confirm and add it to the user `PATH`:

```powershell
Test-Path "$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe"   # expect True

$ompBin  = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$ompBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$ompBin", "User")
}
```

Close all terminals and reopen PowerShell 7.

## 3. Hack Nerd Font

A Nerd Font is required for Oh My Posh glyphs and Terminal-Icons. Easiest path,
using Oh My Posh:

```powershell
oh-my-posh font install hack
```

Fallback (manual): download `Hack.zip` from the Nerd Fonts releases —
<https://github.com/ryanoasis/nerd-fonts/releases> — select all `.ttf` files,
right-click → **Install**. Either way you get two families:

```text
Hack Nerd Font
Hack Nerd Font Mono
```

Set the font in Windows Terminal per profile: **Settings → PowerShell / Ubuntu →
Appearance → Font face →** `Hack Nerd Font Mono`, then save and restart.

## 4. Windows Terminal appearance

The intended look, distilled from the reference `settings.json`:

| Aspect | Value |
|---|---|
| Default profile | **Ubuntu** (WSL) — opens straight into WSL2 |
| Font | **Hack Nerd Font Mono**, size 11 |
| Color scheme | **Dark+** (built-in) |
| Background | solid dark; Ubuntu pane opaque (`opacity 100`, `useAcrylic false`) |
| App theme | **SeamlessDark** — dark `#1E1E1E` tab row blended into the title bar |
| Window | 160 × 40 at launch, centered; tabs always shown, in the title bar |
| Copy / paste | `ctrl+c` copy (multi-line), `ctrl+v` paste; `copyOnSelect` off |
| Find | `ctrl+shift+f` |
| Split pane | `alt+shift+d` (auto split, duplicate) |
| Language | `en-GB`; no confirm on "close all tabs" |

### Apply it

1. In Windows Terminal: **Settings** (`Ctrl+,`) → gear icon → **Open JSON file**.
2. **Back it up first**, in PowerShell 7:

   ```powershell
   $wt = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" |
         Select-Object -First 1
   $settings = Join-Path $wt.FullName "LocalState\settings.json"
   Copy-Item $settings "$settings.bak"     # restore point
   $settings                                # prints the path you're editing
   ```

3. Merge the curated block below into that `settings.json`. Keep the existing
   `profiles.list` entries Windows Terminal generated for you; only add the
   Ubuntu overrides and the top-level/theme/keybinding keys. `settings.json` is
   JSONC, so the `//` comments are fine to keep or delete.

### Curated `settings.json`

```jsonc
{
    "firstWindowPreference": "defaultProfile",
    // Deterministic guid for the WSL distro named "Ubuntu" — matches on any
    // machine where that distro exists. Otherwise pick Ubuntu in the UI.
    "defaultProfile": "{03794fdb-bf56-5b5d-8e08-0186c26a4ad5}",

    "initialCols": 160,
    "initialRows": 40,
    "centerOnLaunch": true,
    "alwaysShowTabs": true,
    "showTabsInTitlebar": true,
    "useAcrylicInTabRow": true,
    "language": "en-GB",
    "copyOnSelect": false,
    "copyFormatting": "none",
    "warning.confirmCloseAllTabs": false,

    "theme": "SeamlessDark",
    "themes": [
        {
            "name": "SeamlessDark",
            "tab":    { "background": "#1E1E1EFF", "unfocusedBackground": "#1E1E1EFF", "iconStyle": "default", "showCloseButton": "hover" },
            "tabRow": { "background": "#1E1E1EFF", "unfocusedBackground": "#1E1E1EFF" },
            "window": { "applicationTheme": "dark", "useMica": false, "experimental.rainbowFrame": false }
        }
    ],

    "profiles": {
        "defaults": {
            "colorScheme": "Dark+",
            "font": { "face": "Hack Nerd Font Mono", "size": 11 },
            "opacity": 100,
            "useAcrylic": true
        },
        "list": [
            {
                // Ubuntu (WSL) — the working profile, kept opaque.
                "guid": "{03794fdb-bf56-5b5d-8e08-0186c26a4ad5}",
                "name": "Ubuntu",
                "source": "Microsoft.WSL",
                "colorScheme": "Dark+",
                "opacity": 100,
                "useAcrylic": false
            }
        ]
    },

    "actions": [
        { "command": { "action": "copy", "singleLine": false }, "id": "User.copy" },
        { "command": "paste", "id": "User.paste" },
        { "command": "find", "id": "User.find" },
        { "command": { "action": "splitPane", "split": "auto", "splitMode": "duplicate" }, "id": "User.splitPane" }
    ],
    "keybindings": [
        { "id": "User.copy",      "keys": "ctrl+c" },
        { "id": "User.paste",     "keys": "ctrl+v" },
        { "id": "User.find",      "keys": "ctrl+shift+f" },
        { "id": "User.splitPane", "keys": "alt+shift+d" }
    ]
}
```

Machine-specific noise from the original file — GUIDs of auto-discovered
profiles, miniconda / VS 2022 profiles, the absolute icon path, and two unused
duplicate color schemes — is intentionally left out; Windows Terminal
regenerates its auto profiles on its own.

## 5. PowerShell 7 prompt — Oh My Posh + Terminal-Icons

Create the profile if missing and open it:

```powershell
New-Item -Path $PROFILE -Type File -Force
notepad $PROFILE
```

Download the `probua.minimal` theme:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.config\oh-my-posh"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/probua.minimal.omp.json" `
  -OutFile "$HOME\.config\oh-my-posh\probua.minimal.omp.json"
Test-Path "$HOME\.config\oh-my-posh\probua.minimal.omp.json"   # expect True
```

Install Terminal-Icons:

```powershell
Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser
```

Put these two lines in `$PROFILE`:

```powershell
oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\probua.minimal.omp.json" | Invoke-Expression
Import-Module Terminal-Icons
```

Reload and test:

```powershell
. $PROFILE
Get-ChildItem        # icons should render
```

## 6. Verification

```powershell
$PSVersionTable.PSVersion
oh-my-posh --version
Get-Module Terminal-Icons -ListAvailable
Test-Path "$HOME\.config\oh-my-posh\probua.minimal.omp.json"
```

Reference (known-good versions at time of writing):

```text
PowerShell     7.6.3
Oh My Posh     29.24.0
Terminal-Icons 0.11.0
Theme          probua.minimal
```

Paths:

```text
PowerShell profile:  $PROFILE
Oh My Posh theme:    C:\Users\<you>\.config\oh-my-posh\probua.minimal.omp.json
WT settings:         %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```
