#!/bin/zsh
# .aliases - Set whatever shell aliases you want.

# Changing/making/removing directory
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

# General aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias -- -='cd -'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias md='mkdir -p'
alias rd=rmdir

function d () {
  if [[ -n $1 ]]; then
    dirs "$@"
  else
    dirs -v | head -n 10
  fi
}
compdef _dirs d

# mask built-ins with better defaults
alias vim=nvim

# more ways to ls
alias ll='ls -lh'
alias la='ls -lAh'
alias lsa='ls -lah'
alias ldot='ls -ld .*'

# fix common typos
alias quit='exit'
alias cd..='cd ..'

# find
alias fd='find . -type d -name' # find directory
alias ff='find . -type f -name' # find file

# misc
alias z="exec zsh"
alias zdot='cd ${ZDOTDIR:-~}'
alias zshrc='${EDITOR:vim} "${ZDOTDIR:-$HOME}"/.zshrc'
alias zbench='for i in {1..10}; do /usr/bin/time zsh -lic exit; done'
alias dots="cd ~/dotfiles"
alias scripts="cd ~/.config/scripts" 

alias print_color_range='for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i} ${(l:3::0:)i} %f "; (( (i + 1) % 8 == 0 )) && print ""; done'
