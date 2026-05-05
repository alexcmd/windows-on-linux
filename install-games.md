# Installing Windows games through Proton (no Steam client)

`proton-run` launches any Windows `.exe` through a Steam Proton build inside
the Steam Linux Runtime "sniper" container, without needing the Steam client
to be running. This works for installers (GOG/Inno, InstallShield, MSI via
msiexec, etc.) and for arbitrary Windows tools.

## Prefix model

Every run uses a **prefix** (a wine install) under
`~/.local/share/Steam/steamapps/compatdata/<PREFIX>/pfx/`.

- `-p NAME` picks the prefix name. Default: `proton-run`.
- Prefixes persist. A single prefix can host multiple installed apps, but
  the cleanest pattern is **one prefix per game** (`-p foo` for the foo
  installer and its subsequent launches).
- `proton-run --list` shows every existing prefix.
- `proton-run --kill -p NAME` nukes the wineserver for that prefix
  (safe, does not touch files).

## Running an installer

```bash
proton-run -p mygame /path/to/setup_mygame.exe
```

First invocation on a fresh prefix runs `wineboot` and takes ~30-120 s on
a Steam Deck (disk + syncs). Subsequent runs reuse the prefix and start
in a second or two.

If nothing visible happens for more than a couple of minutes and the
installer window never shows up, see
[troubleshooting.md — sync() hang](./troubleshooting.md#the-silent-hang-usb--sync-lockup).

## GOG / Inno installer artefacts

A GOG Inno installer places files at paths like:

```
<prefix>/pfx/drive_c/GOG Games/<Game Name>/
<prefix>/pfx/drive_c/proton_shortcuts/<Game Name>.desktop
<prefix>/pfx/drive_c/users/Public/Desktop/<Game Name>.lnk
```

`proton-run --games` reads the `proton_shortcuts/*.desktop` files to list
installed games. The `.desktop` file contains:

- `Name=` — display name
- `Path=` — absolute dir containing the main executable (via `dosdevices`)
- `StartupWMClass=` — the actual exe filename (e.g. `nwmain.exe`)

Uninstaller shortcuts are filtered out by name (matches `Uninstall`,
`Удалить`, `Deinstall`, `Désinstall*`).

## PROTON_LOG — when something misbehaves

```bash
PROTON_LOG=1 proton-run -p mygame /path/to/setup.exe
```

Produces `~/steam-0.log` with full wine `+loaddll,+seh,+err` trace. Useful
for:

- Missing DLL / DLL init failure → see `err:module:` lines near the end.
- Access violation (`c0000005`) → crash in native Linux if possible.
- GPU/audio probe → search for `opengl32`, `vulkan`, `winepulse`.

## Useful per-run env vars

| Var | Effect |
|-----|--------|
| `WINEDLLOVERRIDES="dxgi,d3d11=n,b"` | Force native / builtin DLL loading. |
| `DXVK_HUD=fps,devinfo,memory` | DXVK perf overlay. |
| `PROTON_USE_WINED3D=1` | Skip DXVK; use wine's native D3D (slow). |
| `STEAM_COMPAT_MOUNTS=/extra/path` | Expose an extra path inside the runtime container. |
| `WINEDEBUG=-all` | Silence wine logs (sometimes speeds things up). |

All `PROTON_*`, `WINE*`, `DXVK_*`, `VKD3D_*` env vars are forwarded as-is.
