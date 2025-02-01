
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

# Installation

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin && ~/.local/bin/chezmoi init --apply git@github.com:rdoering/dotfiles.git --branch chezmoi && . ~/.profile
```

This is a chezmoi respository meant to be used by the tool [Chezmoi](https://www.chezmoi.io)

# Force to bootstrap

```bash
chezmoi state delete --bucket entryState --key "${HOME}/bootstrap.sh"
chezmoi apply
```
