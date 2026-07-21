#!/usr/bin/env bash
set -euo pipefail

os="$(uname -s)"
apt_update_done=0
apt_enabled=0

# Collected installation failures. Real install errors are recorded here and
# the script exits non-zero at the end so chezmoi does not mark the run as done
# and retries on the next apply. Soft skips (already installed, repo
# unreachable, package not packaged) are NOT errors.
FAILED=()
record_error() {
    FAILED+=("$1")
    status_line fail tools "$1" >&2
}

status_line() {
    local status="$1"
    local name="$2"
    local message="$3"
    local label="$status"

    case "$status" in
        ok) label=" ok " ;;
        *) label="$(printf '%-4s' "$status")" ;;
    esac

    printf '[%s] %-12s %s\n' "$label" "$name" "$message"
}

# Output der für die Installation ausgeführten Sub-Commands (apt/brew/curl) um
# 3 Spaces einrücken, damit er sich unter die linksbündigen status_line-Zeilen
# schachtelt. set -euo pipefail (oben) erhält den Exit-Code durch die Pipe.
indent() {
    sed 's/^/   /'
}

if [[ -f "$HOME/.profile" ]]; then
    source "$HOME/.profile"
fi

can_sudo() {
    command -v sudo >/dev/null 2>&1 || return 1
    sudo -k >/dev/null 2>&1
    sudo -n true >/dev/null 2>&1
}

if [[ "$os" == Linux ]]; then
    if command -v apt-get >/dev/null 2>&1 && can_sudo; then
        apt_enabled=1
    else
        status_line skip apt "apt-get missing or sudo requires password"
    fi
fi

# brew is used on macOS only.
install_brew_pkg() {
    local package="$1"
    local command_name="${2:-$package}"

    if command -v "$command_name" >/dev/null 2>&1; then
        status_line skip "$package" "already installed"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        status_line skip "$package" "brew not found"
        return 0
    fi

    if ! NONINTERACTIVE=1 brew install "$package" 2>&1 | indent; then
        record_error "brew install '$package' failed"
        return 0
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        record_error "'$package' installed via brew but command '$command_name' not found"
    fi
    return 0
}

ensure_apt_update() {
    if [[ "$apt_update_done" -eq 0 ]]; then
        apt_update_done=1
        # Repo unreachability is a soft condition (e.g. VPN off): warn, continue.
        sudo apt-get update 2>&1 | indent || status_line warn apt "update reported errors, continuing"
    fi
}

install_apt_pkg() {
    local package="$1"
    local command_name="${2:-$package}"

    if command -v "$command_name" >/dev/null 2>&1; then
        status_line skip "$package" "already installed"
        return 0
    fi

    if [[ "$apt_enabled" -ne 1 ]]; then
        status_line skip "$package" "apt installation disabled"
        return 0
    fi

    ensure_apt_update

    if ! apt-cache show "$package" >/dev/null 2>&1; then
        status_line skip "$package" "not available in apt"
        return 0
    fi

    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package" 2>&1 | indent; then
        record_error "apt install '$package' failed"
        return 0
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        record_error "'$package' installed via apt but command '$command_name' not found"
    fi
    return 0
}

# macOS -> brew, Linux -> apt only (no brew fallback).
install_tool() {
    local mac_pkg="$1"
    local mac_cmd="${2:-$mac_pkg}"
    local linux_pkg="$3"
    local linux_cmd="${4:-$3}"

    case "$os" in
        Darwin)
            install_brew_pkg "$mac_pkg" "$mac_cmd"
            ;;
        Linux)
            install_apt_pkg "$linux_pkg" "$linux_cmd"
            ;;
        *)
            status_line fail os "unsupported: $os"
            exit 1
            ;;
    esac
}

# globalping on macOS lives in the jsdelivr/globalping tap; on Linux the
# versionless GitHub release tarball is fetched directly. Not in the mise
# registry, so it stays here.
install_globalping_linux() {
    if command -v globalping >/dev/null 2>&1; then
        status_line skip globalping "already installed"
        return 0
    fi
    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *)
            status_line skip globalping "unsupported architecture $(uname -m)"
            return 0
            ;;
    esac
    local url="https://github.com/jsdelivr/globalping-cli/releases/latest/download/globalping_Linux_${arch}.tar.gz"
    local tmp bin
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/archive.tar.gz"; then
        record_error "globalping: download failed ($url)"
        rm -rf "$tmp"
        return 0
    fi
    if ! tar -xzf "$tmp/archive.tar.gz" -C "$tmp"; then
        record_error "globalping: extraction failed"
        rm -rf "$tmp"
        return 0
    fi
    bin="$(find "$tmp" -type f -name globalping -print -quit)"
    if [[ -z "$bin" ]]; then
        record_error "globalping: binary not found in archive"
        rm -rf "$tmp"
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    if ! install -m 0755 "$bin" "$HOME/.local/bin/globalping"; then
        record_error "globalping: install to ~/.local/bin failed"
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    status_line ok globalping "installed to ~/.local/bin"
}

install_globalping() {
    case "$os" in
        Darwin)
            if command -v globalping >/dev/null 2>&1; then
                status_line skip globalping "already installed"
                return 0
            fi
            if ! command -v brew >/dev/null 2>&1; then
                status_line skip globalping "brew not found"
                return 0
            fi
            if ! brew tap jsdelivr/globalping 2>&1 | indent; then
                record_error "brew tap 'jsdelivr/globalping' failed"
                return 0
            fi
            install_brew_pkg "globalping" "globalping"
            ;;
        Linux) install_globalping_linux ;;
    esac
}

# Tailscale stays here because its macOS standalone GUI app needs a wrapper
# script (bundleIdentifier lookup breaks via plain symlink), and the App Store
# variant must not be shadowed by a brew install. The Linux variant uses apt.
install_tailscale() {
    local xdg_bin_dir="${XDG_BIN_DIR:-$HOME/.local/bin}"
    local ts_link="$xdg_bin_dir/tailscale"

    # The macOS standalone Tailscale.app resolves its bundle context from
    # argv[0]; a symlink outside the .app bundle breaks that lookup and
    # crashes with "bundleIdentifier is unknown to the registry". A small
    # wrapper script that execs the real binary avoids this.
    write_wrapper() {
        local target="$1"
        if [[ -L "$ts_link" || -f "$ts_link" ]]; then
            status_line run tailscale "removing old entry at $ts_link"
            rm -f "$ts_link"
        elif [[ -e "$ts_link" ]] && [[ ! -L "$ts_link" && ! -f "$ts_link" ]]; then
            status_line warn tailscale "$ts_link exists and is not a regular file, leaving it in place"
            return 1
        fi
        mkdir -p "$xdg_bin_dir"
        cat > "$ts_link" <<EOF
#!/bin/sh
exec "$target" "\$@"
EOF
        chmod +x "$ts_link"
        status_line ok tailscale "wrapper $ts_link -> $target"
        return 0
    }

    case "$os" in
        Darwin)
            local gui_bin="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
            local mas_receipt="/Applications/Tailscale.app/Contents/_MASReceipt"
            # macOS has two Tailscale variants: the standalone build from
            # tailscale.com (CLI-capable, no _MASReceipt) and the Mac App
            # Store build (sandboxed, CLI unusable). Both ship their own
            # tailscaled daemon, so a brew-installed tailscale alongside
            # either GUI app causes a version mismatch and a conflicting
            # daemon.
            if [[ -x "$gui_bin" ]] && [[ ! -d "$mas_receipt" ]]; then
                if brew list tailscale >/dev/null 2>&1; then
                    status_line run tailscale "removing brew tailscale to avoid daemon conflict with standalone app"
                    brew uninstall tailscale >/dev/null 2>&1 || \
                        status_line warn tailscale "brew uninstall failed, please remove manually"
                fi
                write_wrapper "$gui_bin" && return 0
            elif [[ -x "$gui_bin" ]]; then
                status_line warn tailscale "App Store build present (sandboxed, CLI unusable); brew skipped to avoid daemon conflict"
                status_line warn tailscale "uninstall the App Store app or install the standalone build from tailscale.com"
                return 0
            fi
            install_brew_pkg "tailscale" "tailscale"
            ;;
        Linux)
            install_apt_pkg "tailscale" "tailscale"
            ;;
    esac
}

# at/atd: no brew formula exists (macOS ships /usr/bin/at natively via launchd),
# and mise has no backend for it either (it's a system daemon package with a
# root-owned spool dir, not a portable release binary). Linux uses apt; the
# atd boot-autostart for WSL lives in run_onchange_40_setup-atd-wsl.sh.tmpl.
install_at() {
    case "$os" in
        Darwin)
            if command -v at >/dev/null 2>&1; then
                status_line skip at "already installed (built into macOS)"
            else
                status_line fail at "missing built-in 'at' binary, unexpected on macOS"
            fi
            ;;
        Linux)
            install_apt_pkg "at" "at"
            ;;
    esac
}

# --- System-level tools (not in the mise registry) ---------------------------
# Dev tools (starship, ripgrep, fzf, tmux, neovim, zoxide, yazi, atuin, delta,
# fd, etc.) are managed by mise via ~/.config/mise/config.toml. Only tools
# that need brew/apt or have macOS GUI integration logic remain here.
#
# btop, eza: on macOS these are Linux-only in mise (btop has no macOS release
# assets; eza's asdf plugin is hardcoded to x86_64). They fall back to brew.
# On Intel Macs (Rosetta) atuin/delta/fd would also need brew fallback since
# their aqua backends only ship darwin/arm64 binaries. This script does not
# auto-detect Rosetta — if you run on an Intel Mac, add the brew fallbacks
# for atuin/delta/fd manually.

install_tool "zsh"     "zsh"     "zsh"       "zsh"
install_tool "unzip"   "unzip"   "unzip"     "unzip"
install_tool "p7zip"   "7z"      "p7zip-full" "7z"
install_tool "sysbench" "sysbench" "sysbench" "sysbench"
install_globalping
install_tailscale
install_at

# macOS fallbacks for tools that mise cannot install on darwin.
case "$os" in
    Darwin)
        install_brew_pkg "btop" "btop"
        install_brew_pkg "eza"  "eza"
        ;;
esac

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo >&2
    status_line fail tools "finished with ${#FAILED[@]} error(s)" >&2
    for e in "${FAILED[@]}"; do
        echo "  - $e" >&2
    done
    exit 1
fi

status_line ok tools "all processed successfully"
