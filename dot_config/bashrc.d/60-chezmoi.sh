#!/usr/bin/env bash

if [ ! -f /run/.toolboxenv ]; then
    alias chezmoi="toolbox run chezmoi"
    eval "$(chezmoi completion bash)"
fi
