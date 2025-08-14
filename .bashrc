if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

if ! [[ "$PATH" =~ "$HOME/.local/bin" ]]; then
  PATH="$PATH:$HOME/.local/bin"
fi
export PATH

export XDG_CONFIG_HOME="$HOME"/.config
export XDG_CACHE_HOME="$HOME"/.cache
export XDG_DATA_HOME="$HOME"/.local/share
export XDG_STATE_HOME="$HOME"/.local/state
