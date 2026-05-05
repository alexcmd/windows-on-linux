# Non-Steam shortcuts — adding games to the Steam library

Shortcuts are stored in two places:

- **Binary VDF**: `~/.local/share/Steam/userdata/<UID>/config/shortcuts.vdf`
  — the shortcut itself (name, exe, startdir, icon, tags).
- **Text VDF**: `~/.local/share/Steam/config/config.vdf`, under
  `InstallConfigStore → Software → Valve → Steam → CompatToolMapping`
  — the Proton version assigned to a given AppID.

**Steam must be closed** when editing either file. Steam rewrites both on
exit and will clobber your edits.

## Adding a shortcut

```bash
steam-shortcut add \
    --name "Game Name" \
    --exe  "/absolute/path/to/exe-or-launcher" \
    --startdir "/absolute/path/to/gamedir" \
    --icon "/path/to/icon.{png,ico}" \
    --tags "GOG,RPG"
```

The AppID is a deterministic 32-bit CRC of `name + exe`, so re-adding
the same shortcut reuses the same AppID (useful for grid art).

## The "Proton on native" gotcha

When Steam sees a new non-Steam shortcut and the exe is not recognisably
a native Linux binary (e.g. it's a `.sh`, or a Windows `.exe`, or has an
unfamiliar extension), it **auto-assigns a Proton build** as the
CompatToolMapping. For a `.exe` this is correct. For a `launch.sh`
wrapping a native ELF it is **wrong and will break the launch**.

### How to spot it

Read `~/.local/share/Steam/config/config.vdf` and look for your AppID
under `CompatToolMapping`:

```
"CompatToolMapping"
{
    "3423411591"
    {
        "name"        "proton_10"     # <-- uh oh
        "config"      ""
        "priority"    "250"
    }
}
```

A separate mapping of the same AppID may appear under `apps` with just
`SizeOnDisk` — that's benign, leave it.

### How to fix

```bash
# 1. Close Steam fully (System tray → Exit, or `steam -shutdown`).
# 2. Clear the mapping:
steam-shortcut clear-compat --appid 3423411591
# 3. Start Steam again.
```

This only removes the single leaf block under `CompatToolMapping` for that
AppID; it leaves `SizeOnDisk` entries intact.

## Minimal flow: GOG native game → Steam library

```bash
# Close Steam first.
SHORT_APPID=$(steam-shortcut appid \
    --name "Neverwinter Nights Enhanced Edition" \
    --exe '"<abs path to launch.sh>"')

steam-shortcut add \
    --name "Neverwinter Nights Enhanced Edition" \
    --exe  "<abs path to launch.sh>" \
    --startdir "<abs path to launch.sh's dir>" \
    --icon "<abs path to .ico>"

# Launch Steam briefly so it writes config.vdf with the auto-assigned tool,
# then close it again.

steam-shortcut clear-compat --appid "$SHORT_APPID"
steam-shortcut grid --appid "$SHORT_APPID" --steam-appid <steam appid>
```

## Compat-tool names

Names used in `CompatToolMapping` correspond to directories under either
`~/.local/share/Steam/steamapps/common/` (e.g. `Proton 10.0` →
`proton_10`) or `~/.local/share/Steam/compatibilitytools.d/`. The Python
wrapper uses Steam's canonical short names (e.g. `proton_10`,
`proton_9`, `proton_experimental`, `GE-Proton*`).

## AppID math (when you need it manually)

```python
import zlib
key  = f'"{exe_quoted}"{name}'
crc  = zlib.crc32(key.encode())
appid_unsigned_64 = (crc | 0x80000000) << 32 | 0x02000000
appid_steamgrid   = crc | 0x80000000           # what grid filenames use
```

`steam-shortcut appid --name N --exe E` prints the grid-style ID.
