#
# https://github.com/jeffreytse/zsh-vi-mode
#

export EDITOR=nvim
autoload -U edit-command-line
zle -N edit-command-line

function do-nothing() {}
zle -N do-nothing


# bindkey flags:
# --------------------------------------------------
# -l    list existing keymap names
# -L    list all keymaps with their key bindings
# -M    list all keybinds for a given keymap (e.g. viins)
# -r    remove keybind
# -a    vim normal mode
# -i    vim insert mode
# -v    use vi keymap for editing
# -e    use emacs keymap for editing
# -N    print name of key sequence for a widget
# -s    bind key sequence to a string to be inserted
# -k    print key sequence for a key name
# -q    print all widgets bound to a given keymap
# --------------------------------------------------

# Unbind up/down arrow keys
bindkey '^[[A' do-nothing
bindkey '^[[B' do-nothing

# Maybe not needed anymore
#
# Force zsh-vi-mode to initialize last to capture all keybindings
# if declare -f zvm_init > /dev/null; then
#     zvm_init
#     ZVM_SYSTEM_CLIPBOARD_ENABLED=true
# fi
