# Prefer native Linux binaries when they exist

Some GOG Windows installers ship a **native Linux binary alongside** the
Windows one. `bin/linux-x86/`, `bin/linux-x86_64/`, and sometimes
`bin/linux/` are the common locations. These are standalone ELF
executables (or shell-launchers) that do not need Proton, DXVK, or the
Steam Linux Runtime container.

Running them natively is usually:

- **More stable.** Avoids flaky wine codepaths; no DXVK/OpenGL translator.
  In particular, some games crash on the Deck's Mesa/radv through Proton
  but run clean through the native binary (e.g. NWN:EE on 6.11 kernel +
  Proton 10 hits `STATUS_ACCESS_VIOLATION` / `0xC0000005` intermittently).
- **Lighter.** No pressure-vessel bwrap container, no full wine prefix
  wake-up.
- **Faster to start.** First-boot of a prefix can be minutes; native
  launch is instant.

## Detection rule used by `proton-run --games`

Given a game's Windows exe at `…/bin/win32/foo.exe`, check siblings under
`…/bin/`:

1. `linux-<arch>/launch.sh` — preferred; GOG convention (e.g. NWN:EE).
2. `linux-<arch>/<game>-linux` or a binary with `.x86_64` / `.x86` suffix.
3. Fallback: `linux/launch.sh` etc.

`<arch>` is `x86_64` on Steam Deck (and modern desktops); `x86` is 32-bit.

If a native launcher is found, `proton-run --run NAME` exec's it directly
(with `chdir` to its directory) instead of going through Proton. Use
`--force-proton` to override.

## Save-file location differs

The native Linux binary generally uses XDG paths
(`~/.local/share/<Game Name>/`, `~/.config/<Game Name>/`), **not** the
wine prefix's `drive_c/users/steamuser/Documents/`. Saves made with one
will not be visible to the other.

If you've already played under Proton and want to migrate to native,
either:

- Copy the save dir from
  `~/.local/share/Steam/steamapps/compatdata/<PREFIX>/pfx/drive_c/users/steamuser/Documents/<Game>/`
  into `~/.local/share/<Game>/`, or
- Symlink one to the other.

## Current catalog check

```bash
proton-run --games
```

The `RUNTIME` column will say `native` or `proton`. Games where native is
available are auto-routed there by `--run` unless `--force-proton` is
passed.
