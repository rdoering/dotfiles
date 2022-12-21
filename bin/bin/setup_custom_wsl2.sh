#!/usr/bin/env bash

set -e
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# add repositories
sudo apt-add-repository --yes --no-update ppa:fish-shell/release-3

# update and install once
sudo apt update --ignore-missing # some repos lurking behind VPN walls
sudo apt install --yes --quiet --ignore-missing --fix-broken fish stow

echo -n "get my dotfiles ... "
if [[ -d ~/.dotfiles ]]
then
    git --git-dir=$(realpath ~/.dotfiles/.git) pull --quiet
    echo "updated"
else
    git clone --quiet https://github.com/rdoering/dotfiles.git ~/.dotfiles
    echo "cloned"
fi

cd ~/.dotfiles && stow */
# brew fish is incompatible with linux fish
rm -rf ~/.config/fish/

chsh --shell $(which fish) $USER

trap - EXIT