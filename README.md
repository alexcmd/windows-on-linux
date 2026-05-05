# Steam Deck (desktop) — playbook

[![CI](https://github.com/alexcmd/windows-on-linux/actions/workflows/ci.yml/badge.svg)](https://github.com/alexcmd/windows-on-linux/actions/workflows/ci.yml)
[![Release](https://github.com/alexcmd/windows-on-linux/actions/workflows/release.yml/badge.svg)](https://github.com/alexcmd/windows-on-linux/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/alexcmd/windows-on-linux)](https://github.com/alexcmd/windows-on-linux/releases/latest)

Runnable notes for installing and launching Windows / native Linux games
on a Steam Deck in desktop mode, outside the Steam client.

## Quick start

```bash
git clone <this-repo> ~/Projects/sdeck
cd ~/Projects/sdeck
./install.sh
```

`install.sh` does everything in one shot:
- Installs `proton-run`, `proton-install`, `steam-shortcut` to `~/.local/bin/`
- Adds `~/.local/bin` to `$PATH` (edits your shell profile if needed)
- Registers `.exe` files to open via Proton (double-click in Dolphin / `xdg-open`)
- Checks for an installed Proton; offers to download Proton-GE if none found

Re-run any time after pulling updates — it's idempotent.

```bash
./install.sh --uninstall   # remove scripts + MIME handler
./install.sh --no-proton   # skip Proton check
```

## Tooling

| Command                          | What it does |
|----------------------------------|--------------|
| `proton-run <app.exe>`           | Run a Windows app through a chosen Proton + Steam Linux Runtime, without Steam. Also does GOG/Inno installers. |
| `proton-run --list`              | Show installed Proton versions and existing prefixes. |
| `proton-run --games`             | List installed games discovered across prefixes (via `drive_c/proton_shortcuts/*.desktop`). Shows whether each has a native Linux build. |
| `proton-run --run NAME`          | Launch a game by substring of its display name / short name / prefix name. Prefers native Linux binary if bundled; falls back to Proton. |
| `proton-run --run NAME --force-proton` | Force the Windows .exe through Proton even if a native binary exists. |
| `proton-run --winecfg \| --regedit \| --shell \| --kill` | Prefix-level utilities. |
| `steam-shortcut add …`           | Create a non-Steam shortcut (binary VDF). Steam must be **closed**. |
| `steam-shortcut clear-compat --appid N` | Drop a Proton compat-tool assignment on a non-Steam shortcut (needed for native Linux games — see [steam-shortcuts.md](./steam-shortcuts.md)). |
| `steam-shortcut grid --appid N --steam-appid M` | Download official library art from the Steam CDN for a non-Steam shortcut. |

Scripts live in `~/.local/bin/`:
- `proton-run`
- `steam-shortcut`
- `proton-install` (GE fetcher)

## Standard workflow (GOG Windows installer → native Linux play)

```bash
# 1. Install. Creates a dedicated Proton prefix under compatdata/<name>.
proton-run -p mygame /path/to/setup_foo.exe

# 2. Discover what's installed.
proton-run --games

# 3. Launch. Native Linux binary is auto-preferred if the game bundles one.
proton-run --run mygame

# 4. Add to Steam library (Steam must be closed).
steam-shortcut add \
    --name "My Game" \
    --exe  "/absolute/path/to/launcher-or-exe" \
    --startdir "/absolute/path/to/gamedir" \
    --icon "/path/to/icon.ico"

# 5. IMPORTANT for native Linux binaries: remove Steam's auto-assigned Proton.
#    Restart Steam once, then:
steam-shortcut clear-compat --appid <shortcut-appid>

# 6. Grid art from Steam CDN (optional but nice).
steam-shortcut grid --appid <shortcut-appid> --steam-appid <steam-appid>
```

## Topics

- [install-games.md](./install-games.md) — running installers through Proton
- [native-linux.md](./native-linux.md) — why & how to prefer native Linux builds
- [steam-shortcuts.md](./steam-shortcuts.md) — non-Steam shortcuts, compat-tool gotcha
- [steam-grid-art.md](./steam-grid-art.md) — Steam CDN endpoints & filename convention
- [troubleshooting.md](./troubleshooting.md) — sync() hangs, wine crashes, prefix issues
