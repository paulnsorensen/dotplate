# claude.zsh - Claude Code CLI utilities and MCP management

# On-demand tool loading (Claude Code v2.0.74+)
export ENABLE_TOOL_SEARCH=true

# Disable claude.ai connectors by default (enable per-profile as needed)
export ENABLE_CLAUDEAI_MCP_SERVERS=false

# ── Quick Access ──────────────────────────────────────────────────────
# _cc_base — common launcher: prepends preamble flag, wraps in tmux unless
# already inside tmux or tmux is not installed.
_cc_base() {
    local -a flags=()
    [[ -f "$AGENTS_DOTFILES/preamble.md" ]] && flags+=(--system-prompt-file "$AGENTS_DOTFILES/preamble.md")
    local -a cmd=(claude "${flags[@]}" "$@")
    local launcher="${DOTFILES_DIR:-$HOME/Dev/dotfiles}/bin/cc-env-exec"
    [[ -x "$launcher" ]] && cmd=("$launcher" "${cmd[@]}")
    if [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
        local session="${${PWD:t}//[.:]/-}"
        tmux new-session -A -s "$session" "${(j: :)${(@q)cmd}}"
    elif [[ -n "$_CC_IN_SESSION" ]] && command -v tmux &>/dev/null; then
        local session="${${PWD:t}//[.:]/-}"
        tmux has-session -t "$session" 2>/dev/null \
            || tmux new-session -d -s "$session" "${(j: :)${(@q)cmd}}"
        tmux switch-client -t "$session"
    else
        "${cmd[@]}"
    fi
}

cc()  { _cc_base "$@"; }
ccc() { _cc_base --continue "$@"; }
ccr() { _cc_base --resume "$@"; }

# ── MCP Management ────────────────────────────────────────────────────
CLAUDE_DOTFILES="$DOTFILES_DIR/claude"
AGENTS_DOTFILES="$DOTFILES_DIR/agents"

base-sync() {
    dots profile install base --target "$HOME" \
        --harness claude,codex,cursor,copilot \
        && dots profile install base --target "$HOME/.config/opencode" \
        --harness opencode
}
alias mcp='claude mcp'
alias mcp-ls='claude mcp list'
alias mcp-sync='base-sync'
alias mcp-edit='${EDITOR:-vim} $AGENTS_DOTFILES/mcp/registry.yaml'

# ── Hook Management ───────────────────────────────────────────────────
alias hook-sync='base-sync'
alias hook-edit='${EDITOR:-vim} $AGENTS_DOTFILES/hooks/registry.yaml'
alias hook-ls='yq -r ".hooks | keys | .[]" $AGENTS_DOTFILES/hooks/registry.yaml'

# ── Agent Management ──────────────────────────────────────────────────
alias agent-sync='base-sync'
alias agent-edit='${EDITOR:-vim} $AGENTS_DOTFILES/registry.yaml'
alias agent-ls='yq -r ".agents | keys | .[]" $AGENTS_DOTFILES/registry.yaml'

mcp-add() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: mcp-add <name> <command> [args...]"
        echo "Example: mcp-add my-server npx -y @my/mcp-server"
        return 1
    fi
    local name="$1"
    shift
    claude mcp add -s user "$name" -- "$@"
    echo "Don't forget to add to registry: mcp-edit"
}

# ── Worktree Sessions ─────────────────────────────────────────────────
ccw() {
    if [[ -z "$1" ]]; then
        echo "Usage: ccw <slug> [claude args...]"
        echo "  ccw add-auth          Launch claude in .worktrees/add-auth"
        echo "  ccw add-auth --resume Resume last session in that worktree"
        return 1
    fi

    local slug="$1"
    shift

    local ccw_init="${DOTFILES_DIR}/bin/ccw-init"
    if [[ ! -f "${ccw_init}" ]]; then
        local repo_root
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
        ccw_init="${repo_root}/bin/ccw-init"
    fi

    if [[ ! -f "${ccw_init}" ]]; then
        echo "ccw-init not found" >&2
        return 1
    fi

    local result
    result="$("${ccw_init}" "${slug}")" || return 1

    local wt_path
    wt_path="$(echo "$result" | jq -er '.path')" || { echo "ccw: failed to parse worktree path" >&2; return 1; }
    [[ -d "$wt_path" ]] || { echo "ccw: worktree path not found: $wt_path" >&2; return 1; }

    cd "${wt_path}" && _CC_IN_SESSION=1 cc "$@"
}

ccw-clean() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Not a git repository"
        return 1
    fi
    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"
    ccw-sweep --path "$repo_root" "$@"
}

alias ccw-sweep='$DOTFILES_DIR/bin/ccw-sweep'
alias ccw-ls='git worktree list'
alias ccw-check='$DOTFILES_DIR/bin/ccw-check'

# ── Config Shortcuts ──────────────────────────────────────────────────
alias claude-settings='${EDITOR:-vim} ~/.claude/settings.json'

# ── Plugin Management ─────────────────────────────────────────────────
alias plugin='claude plugin'
alias plugin-ls='claude plugin list'
alias plugin-sync='$CLAUDE_DOTFILES/plugins/sync.sh'
alias plugin-sync-dry='$CLAUDE_DOTFILES/plugins/sync.sh --dry-run'
alias plugin-edit='${EDITOR:-vim} $CLAUDE_DOTFILES/plugins/registry.yaml'

plugin-refresh() {
    local plugin_name="${1:-}"
    local marketplace="${2:-local}"
    if [[ -z "$plugin_name" ]]; then
        echo "Usage: plugin-refresh <plugin-name> [marketplace]"
        return 1
    fi
    local cache_dir="$HOME/.claude/plugins/cache/$marketplace/$plugin_name"

    echo "Refreshing $plugin_name@$marketplace"
    echo "  -> marketplace update $marketplace"
    claude plugin marketplace update "$marketplace" || return 1

    if [[ -d "$cache_dir" ]]; then
        echo "  -> clearing $cache_dir"
        rm -rf "$cache_dir"
    fi

    echo "  -> reinstalling $plugin_name"
    if ! claude plugin update "$plugin_name" -s user 2>/dev/null; then
        claude plugin install -s user "$plugin_name@$marketplace" || return 1
    fi

    echo "Done. Restart Claude Code to apply."
}

# ── Cursor plugins ────────────────────────────────────────────────────
alias cursor-plugin-edit='${EDITOR:-vim} $DOTFILES_DIR/cursor/plugins/local'
alias cursor-plugin-sync='chezmoi apply --force --source $DOTFILES_DIR/chezmoi'
alias cursor-plugin-ls='ls -la ~/.cursor/skills/ ~/.cursor/rules/ ~/.cursor/commands/ ~/.cursor/hooks/ 2>/dev/null'
