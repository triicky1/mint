#!/bin/zsh
# .zshenv - Zsh environment file, loaded always.

# NOTE: .zshenv needs to live at ~/.zshenv, not in $ZDOTDIR!
# FIX THIS BY PASTING THE FOLLOWING TWO LINES INSIDE ~/.zshenv
#		export ZDOTDIR="$HOME/.config/zsh"
#		. $ZDOTDIR/.zshenv


# Set ZDOTDIR if you want to re-home Zsh.
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
export PYTHONPATH="$HOME/.config/python${PYTHONPATH:+:$PYTHONPATH}"
export SHLIB="$HOME/Projects/shlib"
export DBX_CONTAINER_MANAGER=docker

# Export secret environment variables such as API tokens and passwords.
#
# You export secret variables inside this file ~/.config/zsh/.secrets.
# This file will always be ignored inside the global ~/.gitignore, which
# prevents you from accidentally leaking these secrets by never tracking
# this file to begin with.
if [[ -f "$ZDOTDIR/.secrets" ]]; then
    . "$ZDOTDIR/.secrets"
fi

# Ensure path arrays do not contain duplicates.
typeset -gU path fpath

# Set the list of directories that zsh searches for commands.
path=(
  $HOME/{,s}bin(N)
  $HOME/.local/{,s}bin(N)
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  $path
)
