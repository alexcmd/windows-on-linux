# Troubleshooting

## The silent hang: USB + sync() lockup

### Symptom

`proton-run` launches an installer, prints:

```
Proton: Upgrading prefix from None to 10.1000-105 (…)
```

…and then nothing. No installer window. The `python3 proton` process is
present but in **D state** (uninterruptible sleep). `kill -9` on it does
nothing — the process can't be reaped.

### Cause

Proton's prefix-creation path calls `os.sync()`. `sync()` flushes **every**
mounted filesystem. If even one block device has a stuck write queue (most
commonly a flaky USB drive whose FUSE daemon — e.g. `mount.exfat` — is
wedged), `sync()` will not return until that device drains.

Tell-tale evidence (`ps aux | awk '$8~/D/'`):

```
root   … D  [kworker/u32:…+flush-8:0]
root   … D  [usb-storage]
root   … D  /usr/bin/mount.exfat /dev/sda1 /run/media/deck/CDs …
deck   … D  python3 …/Proton 10.0/proton waitforexitandrun …
```

`flush-8:0` = kworker for block device major/minor `8:0`, i.e. `/dev/sda`.

### Fix

Unplug the offending USB drive. If you can't, offline the block device
(requires root):

```bash
sudo sh -c 'echo 1 > /sys/block/sdX/device/delete'
```

The stuck D-state processes will drain within seconds of the device
going away. `rm -rf` the half-made prefix
(`~/.local/share/Steam/steamapps/compatdata/<NAME>`) and retry
`proton-run`.

### Prevention

If you work with removable media a lot, get into the habit of
`proton-run --list` before starting a big install — it touches
compatdata but not sync; if _that_ hangs you have a storage problem.

---

## Game crash `STATUS_ACCESS_VIOLATION` / `0xC0000005` through Proton

### Symptom

Game launches through Proton, then crashes to a "Please report this
crash" dialog. Crash report in the prefix at something like:

```
<prefix>/pfx/drive_c/users/steamuser/Documents/<Game>/crashreport/*.txt
```

`exception = c0000005` means a memory access violation. Common on Steam
Deck with radv/Mesa + older OpenGL games through wined3d/DXVK.

### Fix

1. Check if the game bundles a **native Linux binary**
   (`<game>/bin/linux-x86/` or similar). Use it.
   `proton-run --games` will show `native` in the RUNTIME column.
2. If only Windows is available:
   - Try a different Proton: `-P "Proton 9.0"` or a GE build.
   - `PROTON_USE_WINED3D=1` if DXVK seems to be the trigger.
   - Reduce graphics settings in-game.

---

## Steam launches my native Linux shortcut through Proton and it fails

### Symptom

Added a `launch.sh` for a native Linux game via `steam-shortcut add`.
Clicking it in the Steam library shows a brief "Preparing" dialog and
then nothing, or an error. No game window.

### Cause

Steam auto-assigned a Proton compat tool to the new shortcut's AppID
(`~/.local/share/Steam/config/config.vdf`, `CompatToolMapping` block).
Steam then ran the `.sh` inside a Proton wine prefix, which can't execute
a Linux shell script.

### Fix

Close Steam (`steam -shutdown`), then:

```bash
steam-shortcut clear-compat --appid <AppID>
```

Open Steam again — it now runs `launch.sh` directly.

---

## Prefix corruption / "it worked yesterday"

Quickest reset:

```bash
# Non-destructive: kill wineserver only, prefix files stay.
proton-run --kill -p myprefix

# Full reset: delete the prefix. Loses saves stored in drive_c.
rm -rf ~/.local/share/Steam/steamapps/compatdata/myprefix
```

Back up `pfx/drive_c/users/steamuser/Documents/<Game>` first if the
game stores saves there and you haven't migrated them to XDG paths.

---

## Diagnostics cheat sheet

```bash
# Running wine/proton processes (including container-internal)
ps auxf | grep -E 'wine|proton|pv-adverb|srt-bwrap'

# Anything stuck in uninterruptible I/O
ps aux | awk '$8 ~ /D/'

# Prefix size (watch it grow during install)
du -sh ~/.local/share/Steam/steamapps/compatdata/<PREFIX>/pfx/drive_c

# Wine windows on X11
xwininfo -root -tree | grep '".\+"' | head

# Full wine trace
PROTON_LOG=1 proton-run …      # log to ~/steam-0.log
tail -f ~/steam-0.log | grep -E 'err:|Unhandled|Exception'
```
