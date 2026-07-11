# Windows Terminal — reference notes

**Reference only.** Windows Terminal is configured on the Windows side
(`settings.json`), not in WSL2, so this repo does **not** apply or symlink it.
These notes record the intentional choices so a fresh install can be replicated
by hand. Machine-specific noise (GUIDs, auto-discovered profiles, absolute icon
paths) is deliberately left out.

## Prerequisite

Install the **Hack Nerd Font** on Windows (both the `Mono` and regular variants)
before applying — the terminal font below depends on it.
Source: <https://github.com/ryanoasis/nerd-fonts> (release `Hack.zip`).

## The look, in words

| Aspect | Choice |
|---|---|
| Default profile | **Ubuntu** (WSL) — opens straight into WSL2 |
| Font | **Hack Nerd Font Mono**, size 11 |
| Color scheme | **Dark+** (built-in) |
| App theme | **SeamlessDark** — custom; dark `#1E1E1E` tab row that blends into the title bar |
| Ubuntu pane | opaque (`useAcrylic: false`, `opacity: 100`) |
| Other profiles | acrylic on by default (`profiles.defaults`) |
| Window | 160 × 40 at launch, centered; tabs always shown, in the title bar |
| Copy/paste | `ctrl+c` copy (multi-line), `ctrl+v` paste, `copyOnSelect` off |
| Find | `ctrl+shift+f` |
| Split pane | `alt+shift+d` (auto split, duplicate) |
| Misc | language `en-GB`; no confirm on "close all tabs" |

## How to replicate

1. Install the Hack Nerd Font (above) and restart Windows Terminal.
2. Open **Settings → Open JSON file** (`ctrl+,` then the gear, or `ctrl+shift+,`).
3. Merge the portable subset below into your `settings.json`. Do **not** paste
   GUIDs or the auto-discovered profiles — Windows Terminal regenerates those
   itself. Leave your existing `profiles.list` entries; only add the Ubuntu
   overrides if the profile already exists.
4. Set **Ubuntu** as the default profile (Settings → Startup → Default profile,
   or `defaultProfile` in JSON).

## Portable subset

Trimmed to the intentional settings, free of machine-specific IDs and paths.
`settings.json` is JSONC, so the `//` comments are fine to keep or delete.

```jsonc
{
    "firstWindowPreference": "defaultProfile",
    // Set this to your WSL Ubuntu profile (pick it in the UI, or copy its guid).
    "defaultProfile": "Ubuntu",

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
                // Ubuntu (WSL) — the working profile. Kept opaque.
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

## Notes

- **Auto-discovered profiles** (PowerShell, cmd, Azure Cloud Shell, PowerShell
  Core, Anaconda, Git Bash, VS 2022) are created automatically by Windows
  Terminal from installed sources — not part of this config. Hide the ones you
  don't want with `"hidden": true`.
- The original file carried two unused custom schemes (`Color Scheme 15` / `16`),
  identical to the built-in scheme and referenced by nothing — omitted here; the
  active scheme is the built-in **Dark+**.
- GUIDs and absolute icon paths (e.g. `ubuntu-logo32.png`) are machine-specific
  and intentionally excluded; the terminal regenerates GUIDs on its own.
```
