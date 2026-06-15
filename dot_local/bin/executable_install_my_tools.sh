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
    echo "ERROR: $1" >&2
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
        echo "apt installation disabled: apt-get missing or sudo requires password"
    fi
fi

# brew is used on macOS only.
install_brew_pkg() {
    local package="$1"
    local command_name="${2:-$package}"

    if command -v "$command_name" >/dev/null 2>&1; then
        echo "$package already installed, skipping..."
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "brew not found, cannot install $package, skipping..."
        return 0
    fi

    if ! NONINTERACTIVE=1 brew install "$package"; then
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
        sudo apt-get update || echo "Warning: 'apt-get update' reported errors (continuing)"
    fi
}

install_apt_pkg() {
    local package="$1"
    local command_name="${2:-$package}"

    if command -v "$command_name" >/dev/null 2>&1; then
        echo "$package already installed, skipping..."
        return 0
    fi

    if [[ "$apt_enabled" -ne 1 ]]; then
        echo "apt installation disabled, skipping apt package: $package"
        return 0
    fi

    ensure_apt_update

    if ! apt-cache show "$package" >/dev/null 2>&1; then
        echo "Package '$package' not available in apt, skipping..."
        return 0
    fi

    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"; then
        record_error "apt install '$package' failed"
        return 0
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        record_error "'$package' installed via apt but command '$command_name' not found"
    fi
    return 0
}

# Remove an apt-installed package if present, e.g. to replace an outdated distro
# build with a newer upstream release. No-op if apt is disabled or absent.
remove_apt_pkg_if_present() {
    local package="$1"
    [[ "$apt_enabled" -eq 1 ]] || return 0
    dpkg -s "$package" >/dev/null 2>&1 || return 0
    echo "Removing apt package '$package' (replacing with newer release build)..."
    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$package"; then
        record_error "apt remove '$package' failed"
    fi
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
            echo "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

# --- GitHub release binaries (Linux, for tools not packaged in apt) ----------

rust_target_arch() {
    case "$(uname -m)" in
        x86_64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) echo "" ;;
    esac
}

# Go's GOARCH naming, used by release assets built with goreleaser et al.
go_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *) echo "" ;;
    esac
}

github_latest_tag() {
    local repo="$1" json tag
    # Read into a variable first: a piped `grep -m1`/`head` would close the
    # pipe early, send SIGPIPE to curl and, with `set -o pipefail`, abort the
    # whole script before the caller can handle an empty result.
    json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)" || return 0
    tag="$(printf '%s\n' "$json" | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
    printf '%s\n' "${tag%%$'\n'*}"
}

# Download a .tar.gz, extract the binary named $cmd, install it to ~/.local/bin.
install_tarball_binary() {
    local cmd="$1"
    local url="$2"
    local tmp bin
    tmp="$(mktemp -d)"

    if ! curl -fsSL "$url" -o "$tmp/archive.tar.gz"; then
        record_error "$cmd: download failed ($url)"
        rm -rf "$tmp"
        return 0
    fi
    if ! tar -xzf "$tmp/archive.tar.gz" -C "$tmp"; then
        record_error "$cmd: extraction failed"
        rm -rf "$tmp"
        return 0
    fi

    # -print -quit stops find after the first match itself (no SIGPIPE via head).
    bin="$(find "$tmp" -type f -name "$cmd" -print -quit)"
    if [[ -z "$bin" ]]; then
        record_error "$cmd: binary not found in archive"
        rm -rf "$tmp"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    if ! install -m 0755 "$bin" "$HOME/.local/bin/$cmd"; then
        record_error "$cmd: install to ~/.local/bin failed"
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"

    if [[ -x "$HOME/.local/bin/$cmd" ]]; then
        echo "$cmd installed to ~/.local/bin"
    else
        record_error "$cmd: install verification failed"
    fi
    return 0
}

# Download a raw (uncompressed) release binary directly to ~/.local/bin.
install_raw_binary() {
    local cmd="$1"
    local url="$2"
    local tmp
    tmp="$(mktemp)"
    if ! curl -fsSL "$url" -o "$tmp"; then
        record_error "$cmd: download failed ($url)"
        rm -f "$tmp"
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    if ! install -m 0755 "$tmp" "$HOME/.local/bin/$cmd"; then
        record_error "$cmd: install to ~/.local/bin failed"
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"
    if [[ -x "$HOME/.local/bin/$cmd" ]]; then
        echo "$cmd installed to ~/.local/bin"
    else
        record_error "$cmd: install verification failed"
    fi
    return 0
}

# Install from the "latest" release using a fixed (versionless) asset name.
# A literal {arch} in the asset name is replaced with the rust arch.
install_github_latest_tarball() {
    local cmd="$1"
    local repo="$2"
    local asset_tmpl="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd already installed, skipping..."
        return 0
    fi
    local arch
    arch="$(rust_target_arch)"
    if [[ -z "$arch" ]]; then
        echo "$cmd: unsupported architecture $(uname -m), skipping..."
        return 0
    fi
    install_tarball_binary "$cmd" \
        "https://github.com/$repo/releases/latest/download/${asset_tmpl//\{arch\}/$arch}"
}

# musl builds are statically linked and thus independent of the host glibc
# version (jammy ships 2.35, while current gnu builds need newer).
install_eza_linux() {
    install_github_latest_tarball "eza" "eza-community/eza" "eza_{arch}-unknown-linux-musl.tar.gz"
}

install_atuin_linux() {
    install_github_latest_tarball "atuin" "atuinsh/atuin" "atuin-{arch}-unknown-linux-musl.tar.gz"
}

# Install a Rust CLI from its GitHub release tarball. The download path uses the
# tag (which may carry a leading "v"), while the asset name uses the version
# without it, i.e. "<cmd>-<tag-without-v>-<arch>-unknown-linux-<libc>.tar.gz".
install_github_tagged_tool() {
    local cmd="$1"
    local repo="$2"
    local libc="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd already installed, skipping..."
        return 0
    fi
    local arch tag
    arch="$(rust_target_arch)"
    if [[ -z "$arch" ]]; then
        echo "$cmd: unsupported architecture $(uname -m), skipping..."
        return 0
    fi
    tag="$(github_latest_tag "$repo")"
    if [[ -z "$tag" ]]; then
        record_error "$cmd: could not determine latest release version"
        return 0
    fi
    install_tarball_binary "$cmd" \
        "https://github.com/$repo/releases/download/${tag}/${cmd}-${tag#v}-${arch}-unknown-linux-${libc}.tar.gz"
}

install_delta_linux() {
    install_github_tagged_tool "delta" "dandavison/delta" "musl"
}

# doggo (Go) names its assets "doggo_<version>_Linux_<arch>.tar.gz" with arch
# x86_64/arm64, so the rust-tool helpers don't fit. Not packaged in apt.
install_doggo_linux() {
    if command -v doggo >/dev/null 2>&1; then
        echo "doggo already installed, skipping..."
        return 0
    fi
    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *)
            echo "doggo: unsupported architecture $(uname -m), skipping..."
            return 0
            ;;
    esac
    local tag
    tag="$(github_latest_tag "mr-karan/doggo")"
    if [[ -z "$tag" ]]; then
        record_error "doggo: could not determine latest release version"
        return 0
    fi
    install_tarball_binary "doggo" \
        "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo_${tag#v}_Linux_${arch}.tar.gz"
}

# yq ships raw per-arch binaries; its tarball names the binary "yq_linux_<arch>"
# (not "yq"), so download the raw binary directly. The apt "yq" is a different,
# unrelated tool, hence GitHub even on Linux.
install_yq_linux() {
    if command -v yq >/dev/null 2>&1; then
        echo "yq already installed, skipping..."
        return 0
    fi
    local arch
    arch="$(go_arch)"
    if [[ -z "$arch" ]]; then
        echo "yq: unsupported architecture $(uname -m), skipping..."
        return 0
    fi
    install_raw_binary "yq" \
        "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
}

# jqp (Go) asset: versionless "jqp_Linux_<arch>.tar.gz" (x86_64/arm64), binary
# named "jqp" inside. Not packaged in apt.
install_jqp_linux() {
    if command -v jqp >/dev/null 2>&1; then
        echo "jqp already installed, skipping..."
        return 0
    fi
    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *)
            echo "jqp: unsupported architecture $(uname -m), skipping..."
            return 0
            ;;
    esac
    install_tarball_binary "jqp" \
        "https://github.com/noahgorstein/jqp/releases/latest/download/jqp_Linux_${arch}.tar.gz"
}

# gron (Go) asset: "gron-linux-<arch>-<version>.tgz" (amd64/arm64), binary named
# "gron" inside. Not packaged in apt.
install_gron_linux() {
    if command -v gron >/dev/null 2>&1; then
        echo "gron already installed, skipping..."
        return 0
    fi
    local arch tag
    arch="$(go_arch)"
    if [[ -z "$arch" ]]; then
        echo "gron: unsupported architecture $(uname -m), skipping..."
        return 0
    fi
    tag="$(github_latest_tag "tomnomnom/gron")"
    if [[ -z "$tag" ]]; then
        record_error "gron: could not determine latest release version"
        return 0
    fi
    install_tarball_binary "gron" \
        "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-linux-${arch}-${tag#v}.tgz"
}

install_just_linux() {
    install_github_tagged_tool "just" "casey/just" "musl"
}

install_zoxide_linux() {
    install_github_tagged_tool "zoxide" "ajeetdsouza/zoxide" "musl"
}

# neovim ships a full runtime (share/nvim), so it cannot be reduced to a single
# binary. Extract the release into a dedicated dir and symlink the binary.
install_neovim_linux() {
    if command -v nvim >/dev/null 2>&1; then
        echo "nvim already installed, skipping..."
        return 0
    fi
    local asset
    case "$(uname -m)" in
        x86_64) asset="nvim-linux-x86_64.tar.gz" ;;
        aarch64 | arm64) asset="nvim-linux-arm64.tar.gz" ;;
        *)
            echo "nvim: unsupported architecture $(uname -m), skipping..."
            return 0
            ;;
    esac
    local url="https://github.com/neovim/neovim/releases/latest/download/$asset"
    local tmp dest
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/nvim.tar.gz"; then
        record_error "nvim: download failed ($url)"
        rm -rf "$tmp"
        return 0
    fi
    dest="$HOME/.local/opt/nvim"
    rm -rf "$dest"
    mkdir -p "$dest"
    if ! tar -xzf "$tmp/nvim.tar.gz" -C "$dest" --strip-components=1; then
        record_error "nvim: extraction failed"
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$dest/bin/nvim" "$HOME/.local/bin/nvim"
    if [[ -x "$HOME/.local/bin/nvim" ]]; then
        echo "nvim installed to $dest (symlinked into ~/.local/bin)"
    else
        record_error "nvim: install verification failed"
    fi
}

# yazi ships its Linux release as a .zip containing two binaries (yazi and ya),
# so neither the tarball helpers nor apt (not packaged) apply. musl build keeps
# it independent of the host glibc version.
install_yazi_linux() {
    if command -v yazi >/dev/null 2>&1; then
        echo "yazi already installed, skipping..."
        return 0
    fi
    local arch
    arch="$(rust_target_arch)"
    if [[ -z "$arch" ]]; then
        echo "yazi: unsupported architecture $(uname -m), skipping..."
        return 0
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        record_error "yazi: unzip not found, cannot extract release"
        return 0
    fi
    local url tmp
    url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-musl.zip"
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/yazi.zip"; then
        record_error "yazi: download failed ($url)"
        rm -rf "$tmp"
        return 0
    fi
    if ! unzip -q "$tmp/yazi.zip" -d "$tmp"; then
        record_error "yazi: extraction failed"
        rm -rf "$tmp"
        return 0
    fi
    mkdir -p "$HOME/.local/bin"
    local cmd bin
    for cmd in yazi ya; do
        bin="$(find "$tmp" -type f -name "$cmd" -print -quit)"
        if [[ -z "$bin" ]]; then
            record_error "yazi: binary '$cmd' not found in archive"
            continue
        fi
        if ! install -m 0755 "$bin" "$HOME/.local/bin/$cmd"; then
            record_error "yazi: install of '$cmd' to ~/.local/bin failed"
        fi
    done
    rm -rf "$tmp"
    if [[ -x "$HOME/.local/bin/yazi" ]]; then
        echo "yazi installed to ~/.local/bin"
    else
        record_error "yazi: install verification failed"
    fi
    return 0
}

install_eza() {
    case "$os" in
        Darwin) install_brew_pkg "eza" "eza" ;;
        Linux) install_eza_linux ;;
    esac
}

install_yazi() {
    case "$os" in
        Darwin) install_brew_pkg "yazi" "yazi" ;;
        Linux) install_yazi_linux ;;
    esac
}

install_delta() {
    case "$os" in
        Darwin) install_brew_pkg "git-delta" "delta" ;;
        Linux) install_delta_linux ;;
    esac
}

install_just() {
    case "$os" in
        Darwin) install_brew_pkg "just" "just" ;;
        Linux) install_just_linux ;;
    esac
}

install_doggo() {
    case "$os" in
        Darwin) install_brew_pkg "doggo" "doggo" ;;
        Linux) install_doggo_linux ;;
    esac
}

install_yq() {
    case "$os" in
        Darwin) install_brew_pkg "yq" "yq" ;;
        Linux) install_yq_linux ;;
    esac
}

install_jqp() {
    case "$os" in
        Darwin) install_brew_pkg "jqp" "jqp" ;;
        Linux) install_jqp_linux ;;
    esac
}

install_gron() {
    case "$os" in
        Darwin) install_brew_pkg "gron" "gron" ;;
        Linux) install_gron_linux ;;
    esac
}

install_atuin() {
    case "$os" in
        Darwin) install_brew_pkg "atuin" "atuin" ;;
        Linux) install_atuin_linux ;;
    esac
}

install_zoxide() {
    case "$os" in
        Darwin) install_brew_pkg "zoxide" "zoxide" ;;
        Linux)
            remove_apt_pkg_if_present "zoxide"
            install_zoxide_linux
            ;;
    esac
}

install_neovim() {
    case "$os" in
        Darwin) install_brew_pkg "neovim" "nvim" ;;
        Linux)
            remove_apt_pkg_if_present "neovim"
            install_neovim_linux
            ;;
    esac
}

# --- official curl installers ------------------------------------------------

# Install a tool via its official `curl ... | bash` installer. $cmd is the
# resulting command; $target is an optional install path to verify when that
# location is not on this script's PATH.
install_via_curl() {
    local cmd="$1"
    local url="$2"
    local target="${3:-}"

    if command -v "$cmd" >/dev/null 2>&1 || { [[ -n "$target" ]] && [[ -x "$target" ]]; }; then
        echo "$cmd already installed, skipping..."
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        record_error "curl not found, cannot install $cmd"
        return 0
    fi
    if ! curl -fsSL "$url" | bash; then
        record_error "$cmd: installer failed ($url)"
        return 0
    fi
    if ! command -v "$cmd" >/dev/null 2>&1 && { [[ -z "$target" ]] || [[ ! -x "$target" ]]; }; then
        record_error "$cmd: installer ran but command not found"
    fi
    return 0
}

install_claude_code() {
    install_via_curl "claude" "https://claude.ai/install.sh" "$HOME/.local/bin/claude"
}

install_opencode() {
    install_via_curl "opencode" "https://opencode.ai/install" "$HOME/.opencode/bin/opencode"
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        echo "starship already installed, skipping..."
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        record_error "curl not found, cannot install starship"
        return 0
    fi

    if ! curl -sS https://starship.rs/install.sh | sh -s -- --yes; then
        record_error "starship install failed"
    fi
    return 0
}

install_starship

install_tool "ripgrep" "rg" "ripgrep" "rg"
install_tool "zsh" "zsh" "zsh" "zsh"
install_tool "fzf" "fzf" "fzf" "fzf"
install_tool "tmux" "tmux" "tmux" "tmux"
install_tool "unzip" "unzip" "unzip" "unzip"
install_tool "rclone" "rclone" "rclone" "rclone"
install_tool "restic" "restic" "restic" "restic"
install_tool "sysbench" "sysbench" "sysbench" "sysbench"
install_tool "gh" "gh" "gh" "gh"
install_yazi
install_delta
install_zoxide
install_atuin
install_tool "fd" "fd" "fd-find" "fdfind"
install_eza
install_tool "p7zip" "7z" "p7zip-full" "7z"
install_tool "marksman" "marksman" "marksman" "marksman"
install_neovim
install_just
install_doggo
install_yq
install_jqp
install_gron
install_claude_code
install_opencode

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo >&2
    echo "Installation finished with ${#FAILED[@]} error(s):" >&2
    for e in "${FAILED[@]}"; do
        echo "  - $e" >&2
    done
    exit 1
fi

echo "All tools processed successfully."
