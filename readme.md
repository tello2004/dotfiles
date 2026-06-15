# Martín's $HOME

opinionated configuration files, probably not for you. exclusively made for Fedora Silverblue.

## installation

```bash
toolbox create && toolbox run sudo dnf install chezmoi
toolbox chezmoi init --apply tello2004
systemctl reboot # to load up needed environment variables
```

## direnv

[direnv](https://direnv.net/) is installed at `~/.local/bin` through chezmoi. it comes with cool helpers for toolbx based on [box-direnv](https://github.com/Thesola10/box-direnv):

```bash
# ~/Documentos/Código/project/.envrc
use toolbox <<< "
sudo dnf install @c-development golang delve
sudo dnf clean all
"

toolbox_export git
```

if `direnv allow`ed this project configuration file will:
1. create a toolbox called `project-toolbox`
2. read and run /dev/stdin as a script
3. forcefully export container's `git` binary
  - because normally it will export only binaries that are not already in host's $PATH as wrappers, to avoid performance and compatibility issues.

it sadly comes with a start up penalization of ~1s. i do not care, personally. /shrug
