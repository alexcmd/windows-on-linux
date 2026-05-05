#!/usr/bin/env bash
# install.sh — End-to-end setup: Proton wrapper tools + .exe file handler.
#
# What it does:
#   1. Installs bin/{proton-run,proton-install,steam-shortcut} to ~/.local/bin/
#   2. Ensures ~/.local/bin is in PATH (edits ~/.bash_profile / ~/.bashrc)
#   3. Installs + registers the .exe → proton-run MIME handler (Dolphin, xdg-open, etc.)
#   4. Registers .exe with binfmt_misc so ./foo.exe works in any shell/script
#      Persistence: /etc/binfmt.d/proton.conf (systemd) or user systemd service fallback
#      Shell hooks: command_not_found_handle/handler added to bash/zsh rc files
#   5. Checks for an installed Proton version; offers to install if none found
#
# Usage:
#   ./install.sh              # interactive (prompts for Proton install if missing)
#   ./install.sh --no-proton  # skip Proton check entirely
#   ./install.sh --uninstall  # remove scripts, MIME handler, binfmt (leaves Proton)
#
# Idempotent — safe to re-run after updating scripts.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$SCRIPT_DIR/bin"
BIN_DST="$HOME/.local/bin"
APPS_DST="$HOME/.local/share/applications"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
DESKTOP_ID="proton-run-exe.desktop"
BINFMT_NAME="proton-exe"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    GRN='\033[0;32m' YLW='\033[1;33m' BLU='\033[0;34m'
    RED='\033[0;31m' BLD='\033[1m'     RST='\033[0m'
else
    GRN='' YLW='' BLU='' RED='' BLD='' RST=''
fi

ok()     { printf "${GRN}  ✔${RST}  %s\n" "$*"; }
skip()   { printf "${YLW}  –${RST}  %s\n" "$*"; }
info()   { printf "${BLU}  →${RST}  %s\n" "$*"; }
warn()   { printf "${YLW}  !${RST}  %s\n" "$*"; }
die()    { printf "${RED}  ✘${RST}  %s\n" "$*" >&2; exit 1; }
hdr()    { printf "\n${BLD}%s${RST}\n" "$*"; }

# Try to write content to a file: first without sudo, then with.
# Returns 0 on success, 1 if both attempts fail.
try_write() {
    local content="$1" dest="$2"
    # Wrap in a group so the shell's own redirection error goes to /dev/null too
    if { printf '%s' "$content" > "$dest"; } 2>/dev/null; then return 0; fi
    if command -v sudo >/dev/null 2>&1; then
        { printf '%s' "$content" | sudo tee "$dest" >/dev/null; } 2>/dev/null && return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
NO_PROTON=0
UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        --no-proton)  NO_PROTON=1;;
        --uninstall)  UNINSTALL=1;;
        -h|--help)
            sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p;}' "$0"
            exit 0
            ;;
        *) die "Unknown flag: $arg  (use --help)";;
    esac
done

# ---------------------------------------------------------------------------
# Uninstall path
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
    hdr "Uninstalling"

    for script in proton-run proton-install steam-shortcut; do
        dst="$BIN_DST/$script"
        if [ -f "$dst" ]; then rm -f "$dst"; ok "Removed $dst"
        else skip "$script (not installed)"; fi
    done

    dst="$APPS_DST/$DESKTOP_ID"
    if [ -f "$dst" ]; then
        rm -f "$dst"
        update-desktop-database "$APPS_DST" 2>/dev/null || true
        ok "Removed MIME handler $DESKTOP_ID"
    else
        skip "$DESKTOP_ID (not installed)"
    fi

    # binfmt_misc — disable live entry
    BINFMT_ENTRY_FILE="/proc/sys/fs/binfmt_misc/$BINFMT_NAME"
    if [ -f "$BINFMT_ENTRY_FILE" ]; then
        try_write '-1' "$BINFMT_ENTRY_FILE" && ok "Removed binfmt_misc entry" || \
            warn "Could not remove binfmt entry (try with sudo)"
    else
        skip "binfmt_misc entry (not registered)"
    fi

    # binfmt persistence
    for f in /etc/binfmt.d/proton.conf /usr/lib/binfmt.d/proton.conf; do
        if [ -f "$f" ]; then
            { rm -f "$f" || sudo rm -f "$f"; } 2>/dev/null && ok "Removed $f" || \
                warn "Could not remove $f"
        fi
    done

    # User systemd service
    SVC="$HOME/.config/systemd/user/proton-binfmt.service"
    if [ -f "$SVC" ]; then
        systemctl --user disable --now proton-binfmt.service 2>/dev/null || true
        rm -f "$SVC"
        systemctl --user daemon-reload 2>/dev/null || true
        ok "Removed user systemd service"
    else
        skip "user systemd service (not installed)"
    fi

    warn "Shell rc hooks (command_not_found_handle) were not removed — edit rc files manually."
    warn "PATH entry in your shell profile was not removed (harmless to leave)."
    warn "Proton itself was not removed. Use proton-install remove <VERSION> if needed."
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
hdr "Prerequisites"

if [ -d "$STEAM_ROOT" ]; then
    ok "Steam: $STEAM_ROOT"
else
    warn "Steam not found at $STEAM_ROOT"
    warn "Set STEAM_ROOT env var if Steam is installed elsewhere."
fi

for cmd in xdg-mime update-desktop-database curl python3; do
    if command -v "$cmd" >/dev/null 2>&1; then ok "$cmd"
    else warn "$cmd not found — some features may not work"; fi
done

# ---------------------------------------------------------------------------
# 2. Scripts → ~/.local/bin/
# ---------------------------------------------------------------------------
hdr "Installing scripts → $BIN_DST"

mkdir -p "$BIN_DST"

SCRIPTS=(proton-run proton-install steam-shortcut)
for script in "${SCRIPTS[@]}"; do
    src="$BIN_SRC/$script"
    dst="$BIN_DST/$script"
    [ -f "$src" ] || die "Missing: $src  (run install.sh from the project root)"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        skip "$script (already up to date)"
    else
        install -m 755 "$src" "$dst"
        ok "Installed $script"
    fi
done

# ---------------------------------------------------------------------------
# 3. PATH
# ---------------------------------------------------------------------------
hdr "PATH"

if [[ ":${PATH}:" == *":${BIN_DST}:"* ]]; then
    ok "~/.local/bin already in PATH"
else
    PROFILE_FILE=""
    for f in "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$f" ]; then PROFILE_FILE="$f"; break; fi
    done

    PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

    if [ -n "$PROFILE_FILE" ]; then
        if grep -qF "$PATH_LINE" "$PROFILE_FILE" 2>/dev/null; then
            skip "PATH line already in $PROFILE_FILE"
        else
            printf '\n# Added by sdeck/install.sh\n%s\n' "$PATH_LINE" >> "$PROFILE_FILE"
            ok "Added ~/.local/bin to PATH in $(basename "$PROFILE_FILE")"
            warn "Run: source $PROFILE_FILE  (or open a new terminal)"
        fi
    else
        warn "No shell profile found. Add manually:  $PATH_LINE"
    fi
fi

# ---------------------------------------------------------------------------
# 4. .exe MIME handler (file manager / xdg-open)
# ---------------------------------------------------------------------------
hdr "Registering .exe handler (file manager)"

mkdir -p "$APPS_DST"

PROTON_RUN_BIN="$BIN_DST/proton-run"

DESKTOP_CONTENT="[Desktop Entry]
Type=Application
Version=1.0
Name=Run with Proton
Comment=Run a Windows .exe through Steam's Proton (proton-run)
Exec=${PROTON_RUN_BIN} %f
Icon=wine
Terminal=false
StartupNotify=true
MimeType=application/x-ms-dos-executable;application/x-msdownload;
Categories=Utility;
NoDisplay=true"

DESKTOP_DST="$APPS_DST/$DESKTOP_ID"
if [ -f "$DESKTOP_DST" ] && [ "$(cat "$DESKTOP_DST")" = "$DESKTOP_CONTENT" ]; then
    skip "$DESKTOP_ID (already up to date)"
else
    printf '%s\n' "$DESKTOP_CONTENT" > "$DESKTOP_DST"
    ok "Installed $DESKTOP_ID"
fi

update-desktop-database "$APPS_DST" 2>/dev/null && ok "Desktop database updated" || true

for mime in application/x-ms-dos-executable application/x-msdownload; do
    xdg-mime default "$DESKTOP_ID" "$mime"
    ok "Registered: $mime"
done

# ---------------------------------------------------------------------------
# 5. CLI handler — binfmt_misc + shell hooks
# ---------------------------------------------------------------------------
hdr "Registering .exe handler (CLI)"

BINFMT_ENTRY=":${BINFMT_NAME}:E::exe::${PROTON_RUN_BIN}:"
BINFMT_REG="/proc/sys/fs/binfmt_misc/register"
BINFMT_ENTRY_FILE="/proc/sys/fs/binfmt_misc/${BINFMT_NAME}"

# --- binfmt_misc: kernel-level, covers ./foo.exe in any shell or script ----
BINFMT_OK=0
if [ ! -d /proc/sys/fs/binfmt_misc ]; then
    warn "binfmt_misc filesystem not mounted — skipping kernel registration"
    info "(./foo.exe won't auto-run; use 'proton-run foo.exe' or the file manager)"
elif [ ! -f "$BINFMT_REG" ]; then
    warn "binfmt_misc is mounted but register file is missing"
else
    # Remove stale entry so we can re-register cleanly
    if [ -f "$BINFMT_ENTRY_FILE" ]; then
        try_write '-1' "$BINFMT_ENTRY_FILE" || true
    fi

    if try_write "$BINFMT_ENTRY" "$BINFMT_REG"; then
        ok "binfmt_misc: ./foo.exe now runs via proton-run (active now)"
        BINFMT_OK=1
    else
        warn "Could not write to binfmt_misc/register (no write access)"
        info "Re-run with sudo, or add manually:"
        info "  printf '%s' '${BINFMT_ENTRY}' | sudo tee $BINFMT_REG"
    fi
fi

# --- persistence: survive reboots ------------------------------------------
if [ "$BINFMT_OK" -eq 1 ]; then

    # Preferred: /etc/binfmt.d/ — read by systemd-binfmt on every boot
    MADE_PERSISTENT=0
    for bfdir in /etc/binfmt.d /usr/lib/binfmt.d; do
        if try_write "${BINFMT_ENTRY}"$'\n' "$bfdir/proton.conf"; then
            ok "Persistent: $bfdir/proton.conf (loaded by systemd-binfmt on boot)"
            sudo systemctl restart systemd-binfmt 2>/dev/null || true
            MADE_PERSISTENT=1
            break
        fi
    done

    # Fallback: user systemd one-shot service (e.g. SteamOS read-only /etc)
    if [ "$MADE_PERSISTENT" -eq 0 ]; then
        SVC_DIR="$HOME/.config/systemd/user"
        SVC_FILE="$SVC_DIR/proton-binfmt.service"
        mkdir -p "$SVC_DIR"
        cat > "$SVC_FILE" << EOF
[Unit]
Description=Register proton-run as .exe binfmt_misc handler
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'printf "%s" "${BINFMT_ENTRY}" > /proc/sys/fs/binfmt_misc/register'

[Install]
WantedBy=default.target
EOF
        if systemctl --user daemon-reload 2>/dev/null && \
           systemctl --user enable --now proton-binfmt.service 2>/dev/null; then
            ok "Persistent: user systemd service (proton-binfmt.service)"
            warn "This service needs write access to binfmt_misc at login (may need sudo)."
        else
            warn "Could not enable user systemd service."
            warn "binfmt_misc handler is active now but will be lost on reboot."
            info "To re-register after reboot:"
            info "  printf '%s' '${BINFMT_ENTRY}' | sudo tee $BINFMT_REG"
        fi
    fi
fi

# --- shell hooks: command_not_found — covers 'foo.exe' without ./ ----------
#
# binfmt_misc handles './foo.exe' (file found, routed through kernel exec).
# These hooks handle 'foo.exe' typed without a path (command-not-found path).
# They do NOT replace binfmt_misc for './foo.exe'.

HOOK_MARKER='# sdeck: proton-run .exe hook'

read -r -d '' BASH_HOOK << 'HOOKEOF' || true
# sdeck: proton-run .exe hook
command_not_found_handle() {
    case "$1" in
        *.exe|*.EXE)
            if [ -f "$1" ]; then exec proton-run "$@"; fi
            ;;
    esac
    printf 'bash: %s: command not found\n' "$1" >&2
    return 127
}
HOOKEOF

read -r -d '' ZSH_HOOK << 'HOOKEOF' || true
# sdeck: proton-run .exe hook
command_not_found_handler() {
    case "$1" in
        *.exe|*.EXE)
            if [ -f "$1" ]; then exec proton-run "$@"; fi
            ;;
    esac
    printf 'zsh: %s: command not found\n' "$1" >&2
    return 127
}
HOOKEOF

for rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] || continue
    if grep -qF "$HOOK_MARKER" "$rc"; then
        skip "$(basename "$rc"): command_not_found_handle already present"
    else
        printf '\n%s\n' "$BASH_HOOK" >> "$rc"
        ok "$(basename "$rc"): added command_not_found_handle"
    fi
done

for rc in "$HOME/.zshrc" "$HOME/.zprofile"; do
    [ -f "$rc" ] || continue
    if grep -qF "$HOOK_MARKER" "$rc"; then
        skip "$(basename "$rc"): command_not_found_handler already present"
    else
        printf '\n%s\n' "$ZSH_HOOK" >> "$rc"
        ok "$(basename "$rc"): added command_not_found_handler"
    fi
done

# ---------------------------------------------------------------------------
# 6. Proton check
# ---------------------------------------------------------------------------
if [ "$NO_PROTON" -eq 0 ]; then
    hdr "Proton"

    FOUND_PROTON=""
    if [ -d "$STEAM_ROOT" ]; then
        shopt -s nullglob
        for d in \
            "$STEAM_ROOT/steamapps/common/"Proton*/ \
            "$STEAM_ROOT/compatibilitytools.d"/*/; do
            if [ -x "${d}proton" ] || [ -f "${d}proton" ]; then
                FOUND_PROTON="$(basename "$d")"; break
            fi
        done
        shopt -u nullglob
    fi

    if [ -n "$FOUND_PROTON" ]; then
        ok "Found: $FOUND_PROTON"
        info "Run  proton-install list  to see all versions."
    else
        warn "No Proton version found."
        info "proton-run needs at least one Proton to work."

        if command -v proton-install >/dev/null 2>&1 || [ -x "$BIN_DST/proton-install" ]; then
            printf "\n  Install Proton now? (tries system package manager, falls back to Proton-GE) [y/N] "
            read -r _ans
            if [[ "${_ans:-}" =~ ^[Yy] ]]; then
                "$BIN_DST/proton-install" system
            else
                info "Skipped. Run later:  proton-install system"
            fi
        else
            warn "proton-install not found — install Proton-GE manually or via Steam."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
hdr "Done"
cat <<'EOF'

  Ways to run a Windows .exe:

    ./foo.exe                     kernel-level (binfmt_misc) — any shell, any script
    foo.exe                       shell hook (command_not_found) — interactive shells
    proton-run foo.exe            explicit — always works
    double-click in file manager  MIME handler — Dolphin, Nautilus, Thunar, etc.

  Other commands:
    proton-run -p mygame setup.exe   install into a named prefix
    proton-run --list                show installed Proton versions + prefixes
    proton-run --games               list installed games
    proton-run --run mygame          launch a game by name
    proton-install system            install Proton (PM or Proton-GE fallback)

EOF
