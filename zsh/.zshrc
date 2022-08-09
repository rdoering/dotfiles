# load zgen

if [[ ! -f ${HOME}/.zgen/zgen.zsh ]]
then
  git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
fi
source "${HOME}/.zgen/zgen.zsh"

# if the init scipt doesn't exist

if ! zgen saved
then
echo "Creating a zgen save"
# Disable loading default Prezto modules
# This is necessary due to a quirk of zgen that will load these plugins after
# our custom plugins, overwriting our customizations
# https://github.com/tarjoilija/zgen/issues/74
export ZGEN_PREZTO_LOAD_DEFAULT=0
# prezto options
zgen prezto editor key-bindings 'emacs'
# prezto and modules
zgen prezto
# Default plugins
zgen load sorin-ionescu/prezto modules/environment
zgen load sorin-ionescu/prezto modules/terminal
zgen load sorin-ionescu/prezto modules/editor
zgen load sorin-ionescu/prezto modules/history
zgen load sorin-ionescu/prezto modules/directory
zgen load sorin-ionescu/prezto modules/spectrum
zgen load sorin-ionescu/prezto modules/utility
zgen load sorin-ionescu/prezto modules/completion

#  zgen load sorin-ionescu/prezto modules/prompt

# Extra plugins

#  zgen load sorin-ionescu/prezto modules/git

#  zgen load sorin-ionescu/prezto modules/fasd

zgen load sorin-ionescu/prezto modules/history-substring-search
# 3rd Party plugins
zgen load robbyrussell/oh-my-zsh plugins/docker
zgen load robbyrussell/oh-my-zsh plugins/fasd
zgen load zsh-users/zaw

#  zgen load zsh-users/zsh-autosuggestions

zgen load zsh-users/zsh-completions
zgen load chriskempson/base16-shell
zgen load martinlindhe/base16-iterm2
# zgen prezto homebrew
# zgen prezto archive
zgen prezto command-not-found
zgen prezto osx
zgen prezto ssh
# completions
# zgen load zsh-users/zsh-completions src
zgen load unixorn/autoupdate-zgen
zgen load zsh-users/zsh-syntax-highlighting
zgen load denysdovhan/spaceship-prompt spaceship

# fzf stuff
if ! whence fzf >/dev/null
then
  test -e .fzf2 || rm -rf ~/.fzf
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --no-key-bindings --no-completion  --no-update-rc
fi

# save all to init script
zgen save
fi

source "${HOME}/.zgen/init.zsh"
bindkey "^R" zaw-history
DISABLE_AUTO_UPDATE="true"
DISABLE_LS_COLORS="true"
setopt inc_append_history
setopt share_history

setopt MAGIC_EQUAL_SUBST
compdef -d php

export EDITOR=vim

# ll using iso-format

export TIME_STYLE=long-iso

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
