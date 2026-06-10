# prompt.zsh - Custom powerline-style prompt (vi-mode aware, vcs_info git)
# Colors sourced from zsh/colors.zsh

POWERLINE_LEFT_A_BG=$__SDW_BG_ALT_256
POWERLINE_LEFT_A_FG=$__SDW_FG_256
POWERLINE_LEFT_B_BG=$__SDW_BLUE_256
POWERLINE_LEFT_B_FG=$__SDW_BG_256
POWERLINE_LEFT_C_BG=$__SDW_BG_256
POWERLINE_LEFT_C_FG=$__SDW_DIM_256
POWERLINE_LEFT_D_FG=$__SDW_BLUE_256

POWERLINE_SEPARATOR=$''
POWERLINE_THIN_SEPARATOR=$''

autoload -Uz vcs_info
autoload -Uz add-zsh-hook

add-zsh-hook precmd prompt_precmd

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*:prompt:*' check-for-changes false

local fmt_branch="%b%u%c"
local fmt_action="%a"

zstyle ':vcs_info:*:prompt:*' actionformats "${fmt_branch}${fmt_action}"
zstyle ':vcs_info:*:prompt:*' formats       "${fmt_branch}"
zstyle ':vcs_info:*:prompt:*' nvcsformats   ""

_git_cache_dir=""
_git_cache_head=""
_git_cache_time=""
_git_cache_last_commit=""

PERIOD=30
periodic() {
  prompt_precmd
  zle && zle reset-prompt
}

TRAPWINCH() {
  zle && zle -R
}

function prompt_precmd() {
  fmt_branch="%b%u%c"
  zstyle ':vcs_info:*:prompt:*' formats "${fmt_branch}"
  vcs_info 'prompt'
  render_prompt
}

render_prompt() {
  POWERLINE_LEFT_A="%K{$POWERLINE_LEFT_A_BG}%F{$POWERLINE_LEFT_A_FG} %~ %k%f%F{$POWERLINE_LEFT_A_BG}%K{$POWERLINE_LEFT_B_BG}"$POWERLINE_SEPARATOR
  POWERLINE_LEFT_B="%k%f%F{$POWERLINE_LEFT_B_FG}%K{$POWERLINE_LEFT_B_BG} "${vcs_info_msg_0_}" %k%f%F{$POWERLINE_LEFT_B_BG}%K{$POWERLINE_LEFT_C_BG}"$POWERLINE_SEPARATOR
  POWERLINE_LEFT_C=" %k%f%F{$POWERLINE_LEFT_C_FG}%K{$POWERLINE_LEFT_C_BG}"$(git_time_details)" %k%f%F{$POWERLINE_LEFT_C_BG}"$POWERLINE_SEPARATOR
  POWERLINE_LEFT_D="%k%f%F{$POWERLINE_LEFT_D_FG} %D %T %k%f%F{$POWERLINE_LEFT_D_FG}$POWERLINE_THIN_SEPARATOR%f "

  PROMPT=$POWERLINE_LEFT_A$POWERLINE_LEFT_B$POWERLINE_LEFT_C$POWERLINE_LEFT_D
  RPROMPT=""
}

update_git_cache() {
  local current_dir="$PWD"
  local git_dir=""

  if git_dir=$(git rev-parse --git-dir 2>/dev/null); then
    local git_head_file="${git_dir}/HEAD"
    local current_head=""

    if [[ -f "$git_head_file" ]]; then
      current_head=$(cat "$git_head_file")
    fi

    if [[ "$current_dir" == "$_git_cache_dir" && "$current_head" == "$_git_cache_head" ]]; then
      return 0
    fi

    _git_cache_dir="$current_dir"
    _git_cache_head="$current_head"

    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      _git_cache_last_commit=$(git log -1 --pretty=format:'%at' 2>/dev/null)
    else
      _git_cache_last_commit=""
    fi

    if [[ -n "$_git_cache_last_commit" ]]; then
      local now=$(date +%s)
      local seconds_since=$((now - _git_cache_last_commit))
      _git_cache_time=$(time_since_commit $seconds_since)
    else
      _git_cache_time=""
    fi
  else
    _git_cache_dir=""
    _git_cache_head=""
    _git_cache_time=""
    _git_cache_last_commit=""
  fi
}

git_time_details() {
  update_git_cache
  echo "$_git_cache_time"
}

time_since_commit() {
  seconds_since_last_commit=$(($1 + 0))
  minutes=$((seconds_since_last_commit / 60))
  hours=$((seconds_since_last_commit/3600))
  days=$((seconds_since_last_commit / 86400))
  sub_hours=$((hours % 24))
  sub_minutes=$((minutes % 60))

  if [[ "$hours" -gt 48 ]]; then
    echo "${days}d"
  elif [[ "$hours" -gt 24 ]]; then
    echo "${days}d${sub_hours}h"
  elif [[ "$minutes" -gt 60 ]]; then
    echo "${hours}h${sub_minutes}m"
  else
    echo "${minutes}m"
  fi
}
