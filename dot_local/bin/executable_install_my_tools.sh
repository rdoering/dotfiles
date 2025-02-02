#!/bin/bash

PACKAGES=(
    btop vim ripgrep zsh fzf tmux unzip
    rclone restic sysbench gh yazi git-delta
    zoxide atuin fd
)


command -v brew &>/dev/null || { echo "Failed, run install_brew.sh to install Homebrew first"; exit 1; }
brew install "${PACKAGES[@]}"

