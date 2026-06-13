#!/bin/bash

CATPPUCCIN_DIR="$HOME/.local/share/tmux/plugins/catppuccin"
TPM_DIR="$HOME/.local/share/tmux/plugins/tpm"

if [ ! -d "$CATPPUCCIN_DIR" ]; then
    echo "Catppuccin directory doesn't exist. Cloning repository..."
    mkdir -p "$(dirname "$CATPPUCCIN_DIR")"
    git clone -b v2.1.2 https://github.com/catppuccin/tmux.git "$CATPPUCCIN_DIR"
    echo "Catppuccin tmux theme has been installed successfully."
else
    echo "Catppuccin directory exists. Fetching updates..."
    cd "$CATPPUCCIN_DIR"
    git fetch
    git pull
    echo "Catppuccin tmux theme has been updated successfully."
fi


if [ ! -d "$TPM_DIR" ]; then
    echo "TPM directory doesn't exist. Cloning repository..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    echo "TPM has been installed successfully."
else
    echo "TPM directory exists. Fetching updates..."
    cd "$TPM_DIR"
    git fetch
    git pull
    echo "TPM has been updated successfully."
fi
