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

Run this in **PowerShell 7** (not Windows PowerShell 5.1 — it uses
`System.Text.Json.Nodes`). It backs up your current `settings.json`, then
**merges** the curated keys into it: existing profiles Windows Terminal
auto-generated and any tweaks of your own are preserved, only the curated keys
are added or updated. Windows Terminal hot-reloads on save.

```powershell
# Merge the curated Windows Terminal settings into your live settings.json.
# Your current file is backed up first (rollback); existing profiles/tweaks kept.

$wt = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" |
      Select-Object -First 1
$settings = Join-Path $wt.FullName "LocalState\settings.json"

# 1. Backup for rollback — never clobber an existing pristine backup.
$bak = "$settings.bak"
if (Test-Path $bak) { $bak = "$settings.$(Get-Date -Format yyyyMMdd-HHmmss).bak" }
Copy-Item $settings $bak
Write-Host "Backup -> $bak"

# 2. Parse the live JSONC, tolerating the // comments and trailing commas WT writes.
$o = [System.Text.Json.JsonDocumentOptions]::new()
$o.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
$o.AllowTrailingCommas = $true
$live = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content $settings -Raw), $null, $o)

# 3. Curated settings to merge in (plain JSON; the rationale lives in this doc).
#    Ubuntu's guid is deterministic for the WSL distro named "Ubuntu".
$curated = [System.Text.Json.Nodes.JsonNode]::Parse(@'
{
  "firstWindowPreference": "defaultProfile",
  "defaultProfile": "{03794fdb-bf56-5b5d-8e08-0186c26a4ad5}",
  "initialCols": 160, "initialRows": 40, "centerOnLaunch": true,
  "alwaysShowTabs": true, "showTabsInTitlebar": true,
  "useAcrylicInTabRow": false, "language": "en-GB",
  "copyOnSelect": false, "copyFormatting": "none",
  "warning.confirmCloseAllTabs": false,
  "theme": "SeamlessDark",
  "themes": [ { "name": "SeamlessDark",
    "tab":    { "background": "#1E1E1EFF", "unfocusedBackground": "#1E1E1EFF", "iconStyle": "default", "showCloseButton": "hover" },
    "tabRow": { "background": "#1E1E1EFF", "unfocusedBackground": "#1E1E1EFF" },
    "window": { "applicationTheme": "dark", "useMica": false, "experimental.rainbowFrame": false } } ],
  "profiles": {
    "defaults": { "colorScheme": "Dark+", "font": { "face": "Hack Nerd Font Mono", "size": 11 }, "opacity": 100, "useAcrylic": true },
    "list": [ { "guid": "{03794fdb-bf56-5b5d-8e08-0186c26a4ad5}", "name": "Ubuntu", "source": "Microsoft.WSL", "colorScheme": "Dark+", "opacity": 100, "useAcrylic": false } ]
  },
  "actions": [
    { "command": { "action": "copy", "singleLine": false }, "id": "User.copy" },
    { "command": "paste", "id": "User.paste" },
    { "command": "find", "id": "User.find" },
    { "command": { "action": "splitPane", "split": "auto", "splitMode": "duplicate" }, "id": "User.splitPane" } ],
  "keybindings": [
    { "id": "User.copy", "keys": "ctrl+c" }, { "id": "User.paste", "keys": "ctrl+v" },
    { "id": "User.find", "keys": "ctrl+shift+f" }, { "id": "User.splitPane", "keys": "alt+shift+d" } ]
}
'@)

# 4. Deep-merge. Clone via re-parse so nodes detach from $curated (works on any PS7):
#    objects recurse, arrays of objects upsert by id/guid/name, scalars overwrite.
function Clone-Node($n) { [System.Text.Json.Nodes.JsonNode]::Parse($n.ToJsonString()) }
function Merge-Obj($dst, $src) {
  foreach ($p in @($src.AsObject())) {
    $k = $p.Key; $sv = $p.Value; $dv = $dst[$k]
    if ($sv -is [System.Text.Json.Nodes.JsonObject] -and $dv -is [System.Text.Json.Nodes.JsonObject]) { Merge-Obj $dv $sv }
    elseif ($sv -is [System.Text.Json.Nodes.JsonArray] -and $dv -is [System.Text.Json.Nodes.JsonArray]) { Merge-Arr $dv $sv }
    else { $dst[$k] = Clone-Node $sv }
  }
}
# WT suffixes user action ids with a hash (User.copy.644BA8F2); match on the base
# id so we update the existing binding instead of appending a duplicate.
function BaseId($s) { return ("$s" -replace '\.[0-9A-Fa-f]{8}$', '') }
function Merge-Arr($dst, $src) {
  foreach ($item in @($src)) {
    $key = @('id','guid','name') | Where-Object { $item -is [System.Text.Json.Nodes.JsonObject] -and $item[$_] } | Select-Object -First 1
    $hit = -1
    if ($key) {
      $want = if ($key -eq 'id') { BaseId $item[$key] } else { "$($item[$key])" }
      for ($i = 0; $i -lt $dst.Count; $i++) {
        $have = if ($key -eq 'id') { BaseId $dst[$i][$key] } else { "$($dst[$i][$key])" }
        if ($have -eq $want) { $hit = $i; break }
      }
    }
    if ($hit -ge 0) { Merge-Obj $dst[$hit] $item } else { $dst.Add((Clone-Node $item)) }
  }
}
Merge-Obj $live $curated

# 5. Write back, indented, UTF-8 without BOM (WT hot-reloads).
$wo = [System.Text.Json.JsonWriterOptions]::new(); $wo.Indented = $true
$ms = [System.IO.MemoryStream]::new()
$jw = [System.Text.Json.Utf8JsonWriter]::new($ms, $wo)
$live.WriteTo($jw); $jw.Flush(); $jw.Dispose()
[System.IO.File]::WriteAllBytes($settings, $ms.ToArray())
Write-Host "Merged. Rollback: Copy-Item '$bak' '$settings'"
```

Notes:

- **Rollback**: the script prints a `Copy-Item` line that restores the backup.
- The merge rewrites the file as plain JSON, so any `//` comments you had in
  `settings.json` are dropped — the values are kept.
- Arrays merge by key (`profiles.list` by `guid`, `actions` / `keybindings` by
  `id` — ignoring the hash suffix WT appends, `themes` by `name`), so your
  existing entries are updated in place rather than duplicated.
- Everything else in your `settings.json` is left untouched — the merge only
  writes the curated keys, and Windows Terminal keeps managing its
  auto-generated profiles on its own.

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
