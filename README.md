┳━┓┏━┓┏┓┓┳━┓o┳  ┳━┓┏━┓
┃ ┃┃ ┃ ┃ ┣━ ┃┃  ┣━ ┏━┛
┇━┛┛━┛ ┇ ┇  ┇┇━┛┻━┛┗━┛



>[!info]
> Make sure [GNU Stow](https://www.gnu.org/software/stow/) is installed.

## install

```sh
git clone https://github.com/rdoering/dotfiles.git ~/.dotfiles
stow --dir ~/.dotfiles/home --target ~ .
```

## uninstall

```sh
stow --dir ~/.dotfiles/home --target ~ -D .
```
