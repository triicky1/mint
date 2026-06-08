#!/bin/zsh
#
# .aliases - Set whatever shell aliases you want.
#

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
alias vi=nvim

# more ways to ls
alias ll='ls -lh'
alias la='ls -lAh'
alias lsa='ls -lah'
alias ldot='ls -ld .*'

# fix common typos
alias quit='exit'
alias cd..='cd ..'

# tar
alias tarls="tar -tvf"
alias untar="tar -xf"

# find
alias fd='find . -type d -name'
alias ff='find . -type f -name'

# url encode/decode
alias urldecode='python3 -c "import sys, urllib.parse as ul; \
    print(ul.unquote_plus(sys.argv[1]))"'
alias urlencode='python3 -c "import sys, urllib.parse as ul; \
    print (ul.quote_plus(sys.argv[1]))"'

# misc
alias z="exec zsh"
alias dots="cd ~/dotfiles"
alias please=sudo
alias zshrc='${EDITOR:vim} "${ZDOTDIR:-$HOME}"/.zshrc'
alias zbench='for i in {1..10}; do /usr/bin/time zsh -lic exit; done'
alias zdot='cd ${ZDOTDIR:-~}'
alias print_color_range='for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i} ${(l:3::0:)i} %f "; (( (i + 1) % 8 == 0 )) && print ""; done'
alias temp="nvim ~/temp/scratch -n -c 'setlocal buftype=nofile bufhidden=hide noswapfile'"
alias convert="python3 ~/dotfiles/scripts/calc/convert.py"
alias scripts="cd ~/.config/scripts" 

alias dnfman='if [ -f "$XDG_CONFIG_HOME/scripts/dnfman4dummies.sh" ]; then zsh $XDG_CONFIG_HOME/scripts/dnfman4dummies.sh; fi'
alias dnfhelp=dnfman

alias info='info --vi-keys'
alias hwmonitor='watch -n 1 sensors'

