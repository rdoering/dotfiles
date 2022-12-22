#!/usr/bin/env bash

set -e
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

# add repositories
sudo apt-add-repository --yes --no-update ppa:fish-shell/release-3

# update and install once
sudo apt update --ignore-missing # some repos lurking behind VPN walls
sudo apt install --yes --quiet --ignore-missing --fix-broken fish stow fzf fd-find fdclone

echo -n "get my dotfiles ... "
if [[ -d ~/.dotfiles ]]
then
    git --git-dir=$(realpath ~/.dotfiles/.git) pull --quiet
    echo "updated"
else
    git clone --quiet git@github.com:rdoering/dotfiles.git ~/.dotfiles
    echo "cloned"
fi

cd ~/.dotfiles && stow */

echo -n "enable fish shell ... "
PROFILE_CONTENT=$(cat ~/.profile)
if [[ "$PROFILE_CONTENT" =~ "fish" ]]
then
    echo "did before"
else
    echo "fish" >> ~/.profile
    echo "done"
fi

fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
fish -c "fisher install ilancosman/tide@v5"
fish -c "fisher install PatrickF1/fzf.fish"

trap - EXIT

fish
