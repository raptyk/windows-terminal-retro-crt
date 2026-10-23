# CLAUDE.md

## Project Overview
`windows-terminal-retro-crt` installs four "Retro CRT" profiles for Windows Terminal: phosphor color schemes, CRT pixel shaders and retro fonts. It also has a bilingual (EN/PL) GitHub Pages site in `docs/`.

**Target Platform:** Windows only (scripts must run in Windows PowerShell 5.1 on a clean system; PowerShell 7 is optional).

## How It Works
- **settings.json, not fragments:** profiles (fixed GUIDs) and color schemes from `terminal/retro-crt.json` are merged into every Terminal `settings.json` found (Store, Preview, unpackaged). JSON fragments were tried and dropped: `profiles.defaults` in the user's settings overrides fragment profiles (font, colorScheme, ...).
- **Template tokens:** `__SHADER_DIR__` and `__PWSH_COMMANDLINE__` in `terminal/retro-crt.json` are replaced with JSON-escaped absolute paths by `install.ps1`.
- **Safe edits:** `lib/TerminalSettings.ps1` strips comments (5.1 cannot parse them), backs up `settings.json` to `settings.json.retrocrt-<timestamp>.bak`, removes our entries by GUID / scheme name (plus any leftover `"source": "RetroCRT"` stubs) and appends the new ones. When no `settings.json` exists yet, it creates one with `defaultProfile` = Windows PowerShell.
- **Shader location:** `%LOCALAPPDATA%\Microsoft\Windows Terminal\RetroCRT\shaders`. The Store (MSIX) Terminal and the shells it starts do NOT see new folders directly in `%LOCALAPPDATA%` (e.g. `%LOCALAPPDATA%\RetroCRT`), but do see `Microsoft\Windows Terminal`. For the same reason the font test runs from the repo (`tools\font-test.ps1`), not from AppData.
- **Fonts:** installed per user (`%LOCALAPPDATA%\Microsoft\Windows\Fonts` + `HKCU\...\Fonts` value named after the full font name from the TrueType `name` table). PxPlus fonts are vendored in `fonts/int10h/` (CC BY-SA 4.0; int10h.org returns 403 to scripts). C64 Pro Mono (redistribution not allowed), Terminus and IBM Plex Mono are downloaded from official URLs, pinned by version and SHA256 in `$FontPackages`.
- **Dependencies:** Windows Terminal and PowerShell 7 come from winget, or from the latest GitHub release zips into `%LOCALAPPDATA%\Programs\` when winget is missing (e.g. Windows Sandbox).
- **Terminal restart:** Terminal reads the font list only at process start; all windows share one process.

## Key Files
- `install.ps1` - idempotent installer (`-SkipDependencies` skips Terminal/PowerShell 7).
- `uninstall.ps1` - removes profiles/schemes/shaders; `-RemoveFonts` also removes the installed fonts.
- `lib/TerminalSettings.ps1` - settings.json helpers shared by both scripts.
- `terminal/retro-crt.json` - profile and color scheme definitions.
- `shaders/crt.hlsl` - strong CRT effect (C64 profile, animated with `Time`).
- `shaders/crt-daily.hlsl` - everyday effect; must never resample the image (keeps pixel fonts sharp), must not use `Time` (no constant redraws), and keeps `CORNER_RADIUS` at 0 because the shader area starts at the text, inside the padding.
- `tools/font-test.ps1` (UTF-8 with BOM, required by Windows PowerShell 5.1), `tools/demo.ps1` (screenshot content), `tools/test-shaders.ps1` (compiles shaders with d3dcompiler_47).
- `docs/index.html` - GitHub Pages site; every text exists twice with `data-lang="en"` / `data-lang="pl"`. Screenshots in `docs/screenshots/`.

## Conventions
- Scripts other than `tools/font-test.ps1` stay ASCII-only so Windows PowerShell 5.1 reads them correctly without a BOM.
- Pixel fonts (PxPlus, Terminus) only at 12 pt or 24 pt (16 px grid at 96 DPI).
- When bumping a downloaded font version, update the URL, file list and SHA256 in `install.ps1`, the file list in `uninstall.ps1`, and the font tables in `README.md`, `README.pl.md` and `docs/index.html`.
- Documentation and the website are bilingual: keep `README.md` / `README.pl.md` and both languages in `docs/index.html` in sync.
- Screenshots must not show personal data: use `tools\demo.ps1` with `-d C:\`.
- Test on a clean system in Windows Sandbox: start it with `<vGPU>Disable</vGPU>` (vGPU gives a black screen on hybrid Intel+NVIDIA laptops), map the repo read-only and run `install.ps1` via `wsb exec ... -r ExistingLogin`. Shaders are not applied there (no GPU), everything else is.
