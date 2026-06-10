# vi-mode.zsh - Vi key bindings for zsh
# Source this file to enable vi-style editing in the shell.
# This is NOT sourced by default — add it to your zshrc or core.zsh to opt in.

setopt VI
KEYTIMEOUT=1
bindkey -v
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# Vi mode cursor shapes
function zle-line-init zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    echo -ne '\e[2 q'  # solid block in normal mode
  elif [[ $KEYMAP == main ]] \
    || [[ $KEYMAP == viins ]] \
    || [[ $KEYMAP = '' ]]; then
    echo -ne '\e[5 q'  # blinking beam in insert mode
  fi
  zle reset-prompt
  zle -R
}
zle -N zle-line-init
zle -N zle-keymap-select
