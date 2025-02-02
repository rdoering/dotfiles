#!/bin/bash

# Definiere Installationspfade
LOCAL_DIR="$HOME/.local"
BREW_DIR="$LOCAL_DIR/share/homebrew"
BIN_DIR="$LOCAL_DIR/bin"

mkdir -p "$BREW_DIR"
mkdir -p "$BIN_DIR"

echo "Downloading and extracting Homebrew..."
curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "$BREW_DIR"

echo "Creating symlinks..."
for file in "$BREW_DIR/bin/"*; do
    if [ -x "$file" ]; then
        ln -sf "$file" "$BIN_DIR/$(basename "$file")"
    fi
done

# Überprüfe PATH
source "$HOME/.bashrc"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Warning: $BIN_DIR is not in your PATH"
    echo "Add the following line to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Teste die Installation
if [ -x "$BIN_DIR/brew" ]; then
    echo "Homebrew successfully installed to $BREW_DIR"
    echo "Brew executables linked to $BIN_DIR"
    echo "Run 'brew doctor' to verify the installation"
else
    echo "Installation failed!"
    exit 1
fi
