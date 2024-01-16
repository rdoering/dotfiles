```
 ,gggggggggggg,                                                               
dP"""88""""""Y8b,                I8    ,dPYb,        ,dPYb,                   
Yb,  88       `8b,               I8    IP'`Yb        IP'`Yb                   
 `"  88        `8b            88888888 I8  8I   gg   I8  8I                   
     88         Y8               I8    I8  8'   ""   I8  8'                   
     88         d8   ,ggggg,     I8    I8 dP    gg   I8 dP   ,ggg,     ,g,    
     88        ,8P  dP"  "Y8ggg  I8    I8dP     88   I8dP   i8" "8i   ,8'8,   
     88       ,8P' i8'    ,8I   ,I8,   I8P      88   I8P    I8, ,8I  ,8'  Yb  
     88______,dP' ,d8,   ,d8'  ,d88b, ,d8b,_  _,88,_,d8b,_  `YbadP' ,8'_   8) 
    888888888P"   P"Y8888P"   88P""Y88PI8"88888P""Y88P'"Y88888P"Y888P' "YY8P8P
                                       I8 `8,                                 
                                       I8  `8,                                
                                       I8   8I                                
                                       I8   8I                                
                                       I8, ,8'                                
                                        "Y8P'                                 
```

>[!info]
> Make sure [GNU Stow](https://www.gnu.org/software/stow/) is installed.

## install configs

```sh
git clone https://github.com/rdoering/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && stow */
```

## install configs on WSL2

Run this command inside a Ubuntu installation
```shell
curl -sL https://raw.githubusercontent.com/rdoering/dotfiles/master/bin/bin/setup_custom_wsl2.sh | bash
```

## uninstall configs

```sh
cd ~/.dotfiles && stow -D */
```

## Deal with conflicts

Conflicts like this can be solved by added changes to the repo, solve them and run `stow` again.
```shell
using GNU software: <http://www.gnu.org/gethelp/>
% stow  */
WARNING! stowing fish would cause conflicts:
  * existing target is neither a link nor a directory: .config/fish/config.fish
  * existing target is neither a link nor a directory: .config/fish/fish_variables
WARNING! stowing vim would cause conflicts:
  * existing target is neither a link nor a directory: .vimrc
All operations aborted.
```
For example:
```shell
% stow  --adopt fish
% stow  --adopt vim
% git status
% git reset --hard
% stow */
```
