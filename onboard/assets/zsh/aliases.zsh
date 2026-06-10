# aliases.zsh - All aliases and simple functions

# Git Aliases
alias ga='git add'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gd='git diff'
if command -v difft &>/dev/null; then
  alias gds='GIT_EXTERNAL_DIFF=difft git diff'
fi
alias gdn='git diff --name-only'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gri='git rm --cached "$(git ls-files -i -X .gitignore)"'
alias glc='git config user.email | xargs git log --author'
alias grb='git pull -r origin main'
alias gcom='git checkout main && git pull'

# Navigation
cdd() {
    if [[ -z "$1" ]]; then
        cd "$DEV_DIR"
    else
        cd "$DEV_DIR/$1"
    fi
}
alias cddot='cd $DOTFILES_DIR'

# Utilities
if [[ "$DOTFILES_OS" == "macos" ]]; then
  alias uuidg="/usr/bin/uuidgen | tr 'A-Z' 'a-z' | tee /dev/stderr | tr -d '\n' | pbcopy"
else
  alias uuidg="uuidgen | tr 'A-Z' 'a-z' | tee /dev/stderr | tr -d '\n' | xclip -sel clip"
fi
alias c="code -r ."
alias zrl="source ~/.zshrc"
alias trl='tmux source-file ~/.tmux.conf && echo "tmux config reloaded"'

# Search (ripgrep)
alias rg='rg --smart-case'
alias rga='rg --hidden --no-ignore'
alias rgf='rg --files-with-matches'
alias rgc='rg --count'
alias rgl='rg --files-without-match'
alias todos='rg "TODO|FIXME|HACK|NOTE" -n'

# File listing (eza)
export CLICOLOR=1
if command -v eza &> /dev/null; then
  alias ls='eza'
  alias ll='eza -lh'
  alias la='eza -lah'
  alias l='eza -F'
  alias tree='eza --tree'
else
  if [[ "$DOTFILES_OS" == "macos" ]]; then
    alias ls='ls -G'
    alias ll='ls -lhG'
    alias la='ls -lahG'
    alias l='ls -CFG'
  else
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lah --color=auto'
    alias l='ls -CF --color=auto'
  fi
fi

# bat
if command -v bat &> /dev/null; then
  alias cat='bat'
  alias catn='bat --number'
fi

# delta
if command -v delta &> /dev/null; then
  alias diff='delta'
fi

# ast-grep
if command -v ast-grep &> /dev/null; then
  alias sg='ast-grep'
fi

# opencode
if command -v opencode &> /dev/null; then
  alias oc='opencode'
fi

# Rust modern coreutils
if command -v btm &>/dev/null; then
    alias top='btm'
fi
if command -v dust &>/dev/null; then
    alias du='dust'
fi
if command -v procs &>/dev/null; then
    alias ps='procs'
fi
if command -v tokei &>/dev/null; then
    alias loc='tokei'
fi
if command -v cargo-nextest &>/dev/null; then
    alias cn='cargo nextest run'
    alias cnf='cargo nextest run --failure-output immediate-final'
fi

# Agent Skills
alias skill='npx --yes skills'
alias skill-ls='npx --yes skills list --global'
alias skill-sync='base-sync'
alias skill-edit='${EDITOR:-vim} $DOTFILES_DIR/skills/_registry.yaml'

# Cheatsheet
alias cheat='$DOTFILES_DIR/bin/cheatsheet'
