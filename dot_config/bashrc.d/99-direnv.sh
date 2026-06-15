#!/usr/bin/env bash

[ -f /run/.toolboxenv ] && return
command -v direnv &>/dev/null && eval "$(direnv hook bash)"
