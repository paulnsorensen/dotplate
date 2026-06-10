# dotplate zshrc — sources zsh modules from $DOTFILES_DIR/zsh/

# Platform detection (used by modules for OS-specific behavior)
case "$OSTYPE" in
  darwin*)  export DOTFILES_OS="macos" ;;
  linux*)   export DOTFILES_OS="linux" ;;
esac

# Core module is required — sets DOTFILES_DIR, PATH, history, editor
_dotplate_zsh="${DOTFILES_DIR:-$HOME/Dev/dotplate}/zsh"
source "$_dotplate_zsh/core.zsh"

# Optional modules — loaded when present; catalog adopters add their own here
for _module in completion tools; do
    [[ -f "$_dotplate_zsh/$_module.zsh" ]] && source "$_dotplate_zsh/$_module.zsh"
done

# Additional catalog modules (uncomment or add as you install them)
# [[ -f "$_dotplate_zsh/colors.zsh" ]]    && source "$_dotplate_zsh/colors.zsh"
# [[ -f "$_dotplate_zsh/aliases.zsh" ]]   && source "$_dotplate_zsh/aliases.zsh"
# [[ -f "$_dotplate_zsh/fzf.zsh" ]]       && source "$_dotplate_zsh/fzf.zsh"
# [[ -f "$_dotplate_zsh/prompt.zsh" ]]    && source "$_dotplate_zsh/prompt.zsh"

# Source local customizations
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# opencode
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

unset _dotplate_zsh _module
