# load zgenom
if [[ ! -f ${HOME}/.zgenom/zgenom.zsh ]]
then
  git clone https://github.com/jandamm/zgenom.git "${HOME}/.zgenom"
fi
source "${HOME}/.zgenom/zgenom.zsh"

# if the init script doesn't exist
if ! zgenom saved
then
  echo "Creating a zgenom save"

  # Disable loading default Prezto modules
  # This is necessary due to a quirk of zgenom that will load these plugins after
  # our custom plugins, overwriting our customizations
  # https://github.com/tarjoilija/zgenom/issues/74
  export ZGEN_PREZTO_LOAD_DEFAULT=0

  # prezto options
  zgenom prezto editor key-bindings 'emacs'
  # prezto and modules
  zgenom prezto
  # Default plugins
  zgenom load sorin-ionescu/prezto modules/environment
  zgenom load sorin-ionescu/prezto modules/terminal
  zgenom load sorin-ionescu/prezto modules/editor
  zgenom load sorin-ionescu/prezto modules/history
  zgenom load sorin-ionescu/prezto modules/directory
  zgenom load sorin-ionescu/prezto modules/spectrum
  zgenom load sorin-ionescu/prezto modules/utility
  zgenom load sorin-ionescu/prezto modules/completion

  zgenom load sorin-ionescu/prezto modules/history-substring-search
  zgenom load robbyrussell/oh-my-zsh plugins/fasd

  zgenom load zsh-users/zsh-completions
  zgenom load chriskempson/base16-shell
  zgenom load martinlindhe/base16-iterm2

  zgenom prezto command-not-found
  zgenom prezto osx
  zgenom prezto ssh

  # completions
  zgenom load unixorn/autoupdate-zgenom
  zgenom load zsh-users/zsh-syntax-highlighting
  zgenom load denysdovhan/spaceship-prompt spaceship

  # fzf search
  zgenom load https://github.com/joshskidmore/zsh-fzf-history-search

  # save all to init script
  zgenom save
fi

DISABLE_AUTO_UPDATE="true"
DISABLE_LS_COLORS="true"
setopt inc_append_history
setopt share_history
setopt MAGIC_EQUAL_SUBST
compdef -d php
export EDITOR=vim

# ll using iso-format
export TIME_STYLE=long-iso

# FZF
export FZF_DEFAULT_OPTS=" --color fg+:#ffffff,bg+:#777777"
