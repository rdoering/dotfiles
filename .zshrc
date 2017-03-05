ANTIGEN_DIR=~/.antigen

if [ ! -d ${ANTIGEN_DIR} ] 
then
  echo "download antigen..."
  mkdir -p ${ANTIGEN_DIR}
  curl https://cdn.rawgit.com/zsh-users/antigen/v1.4.1/bin/antigen.zsh > ${ANTIGEN_DIR}/antigen.zsh
fi

source ${ANTIGEN_DIR}/antigen.zsh

antigen use oh-my-zsh

antigen bundle git
antigen bundle sudo
antigen bundle command-not-found
antigen bundle gradle
antigen bundle alexrochas/zsh-extract
antigen bundle alexrochas/zsh-vim-crtl-z
antigen bundle alexrochas/zsh-git-semantic-commits
antigen bundle alexrochas/zsh-path-environment-explorer
antigen bundle zsh-users/zaw

# Syntax highlighting bundle.
antigen bundle zsh-users/zsh-syntax-highlighting

# Load the theme.
antigen theme robbyrussell/oh-my-zsh themes/dst

antigen apply

bindkey '^R' zaw-history
