#!/usr/bin/env bash

[ -f ~/.local/bin/chezmoi ] && rm ~/.local/bin/chezmoi

command -v host-spawn &>/dev/null || sudo dnf install -y host-spawn
command -v chezmoi &>/dev/null || sudo dnf install -y chezmoi
