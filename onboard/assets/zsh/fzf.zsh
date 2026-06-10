# fzf configuration

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
else
    export FZF_DEFAULT_COMMAND='find . -type f'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='find . -type d'
fi

if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
else
    export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

if command -v tree >/dev/null 2>&1; then
    export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
fi

export FZF_DEFAULT_OPTS="$__SDW_FZF_COLORS --height=50% --layout=reverse --border --inline-info"

if [[ ! -f ~/.fzf.zsh ]]; then
    bindkey "^r" history-incremental-search-backward
fi
