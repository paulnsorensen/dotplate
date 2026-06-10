#!/usr/bin/env bats
# Catalog hygiene and structural tests.
# Every catalog file in onboard/catalog/ must:
#   - parse as YAML (yq)
#   - contain a top-level list key
#   - each item has name, pitch, complexity, entry
#   - requires_secret values look like env-var names (^[A-Z][A-Z0-9_]*$)
#   - os values are only "macos" or "linux" when present
#   - files paths in `files` list exist in the repo
#   - entry values are themselves valid YAML
#   - no personal identifiers (owner string, flair tag, live API keys)

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[0]:-$0}}")/.." && pwd)"
CATALOG_DIR="$REPO_ROOT/onboard/catalog"

# ── Presence checks ────────────────────────────────────────────────────────

@test "catalog directory exists" {
    [[ -d "$CATALOG_DIR" ]]
}

@test "mcp.yaml exists" {
    [[ -f "$CATALOG_DIR/mcp.yaml" ]]
}

@test "hooks.yaml exists" {
    [[ -f "$CATALOG_DIR/hooks.yaml" ]]
}

@test "skills.yaml exists" {
    [[ -f "$CATALOG_DIR/skills.yaml" ]]
}

@test "plugins.yaml exists" {
    [[ -f "$CATALOG_DIR/plugins.yaml" ]]
}

@test "packages.yaml exists" {
    [[ -f "$CATALOG_DIR/packages.yaml" ]]
}

@test "zsh.yaml exists" {
    [[ -f "$CATALOG_DIR/zsh.yaml" ]]
}

@test "mac-extras.yaml exists" {
    [[ -f "$CATALOG_DIR/mac-extras.yaml" ]]
}

# ── YAML parse checks ──────────────────────────────────────────────────────

parse_yaml() {
    local f="$1"
    yq '.' "$f" >/dev/null 2>&1
}

@test "mcp.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/mcp.yaml"
}

@test "hooks.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/hooks.yaml"
}

@test "skills.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/skills.yaml"
}

@test "plugins.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/plugins.yaml"
}

@test "packages.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/packages.yaml"
}

@test "zsh.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/zsh.yaml"
}

@test "mac-extras.yaml parses as YAML" {
    parse_yaml "$CATALOG_DIR/mac-extras.yaml"
}

# ── Schema checks (name, pitch, complexity, entry) ──────────────────────────
# For each catalog file, every item must have name, pitch, complexity, entry.

# Helper: validate all items in a catalog file have required fields.
# Prints a failure message and returns 1 if any item is missing a field.
check_required_fields() {
    local file="$1"
    local list_key
    # Detect the top-level list key (first key in the document)
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name pitch complexity entry
        name=$(yq ".${list_key}[$i].name" "$file")
        pitch=$(yq ".${list_key}[$i].pitch" "$file")
        complexity=$(yq ".${list_key}[$i].complexity" "$file")
        entry=$(yq ".${list_key}[$i].entry" "$file")
        if [[ -z "$name" || "$name" == "null" ]]; then
            echo "Item $i in $file is missing 'name'"
            return 1
        fi
        if [[ -z "$pitch" || "$pitch" == "null" ]]; then
            echo "Item $i ($name) in $file is missing 'pitch'"
            return 1
        fi
        if [[ -z "$complexity" || "$complexity" == "null" ]]; then
            echo "Item $i ($name) in $file is missing 'complexity'"
            return 1
        fi
        if [[ -z "$entry" || "$entry" == "null" ]]; then
            echo "Item $i ($name) in $file is missing 'entry'"
            return 1
        fi
    done
}

@test "mcp.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/mcp.yaml"
}

@test "hooks.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/hooks.yaml"
}

@test "skills.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/skills.yaml"
}

@test "plugins.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/plugins.yaml"
}

@test "packages.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/packages.yaml"
}

@test "zsh.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/zsh.yaml"
}

@test "mac-extras.yaml items have name, pitch, complexity, entry" {
    check_required_fields "$CATALOG_DIR/mac-extras.yaml"
}

# ── complexity values ──────────────────────────────────────────────────────

check_complexity_values() {
    local file="$1"
    local list_key
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name complexity
        name=$(yq ".${list_key}[$i].name" "$file")
        complexity=$(yq ".${list_key}[$i].complexity" "$file")
        if [[ "$complexity" != "low" && "$complexity" != "medium" && "$complexity" != "high" ]]; then
            echo "Item $name in $file has invalid complexity '$complexity' (must be low|medium|high)"
            return 1
        fi
    done
}

@test "all catalog items have valid complexity (low|medium|high)" {
    for f in "$CATALOG_DIR"/*.yaml; do
        check_complexity_values "$f"
    done
}

# ── os values ──────────────────────────────────────────────────────────────

check_os_values() {
    local file="$1"
    local list_key
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name os
        name=$(yq ".${list_key}[$i].name" "$file")
        os=$(yq ".${list_key}[$i].os" "$file")
        if [[ "$os" != "null" && "$os" != "macos" && "$os" != "linux" ]]; then
            echo "Item $name in $file has invalid os '$os' (must be macos|linux or absent)"
            return 1
        fi
    done
}

@test "all catalog items have valid os values when present" {
    for f in "$CATALOG_DIR"/*.yaml; do
        check_os_values "$f"
    done
}

# ── requires_secret values ──────────────────────────────────────────────────

check_secret_names() {
    local file="$1"
    local list_key
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name secret
        name=$(yq ".${list_key}[$i].name" "$file")
        secret=$(yq ".${list_key}[$i].requires_secret" "$file")
        if [[ "$secret" != "null" ]]; then
            if ! [[ "$secret" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
                echo "Item $name in $file has requires_secret '$secret' which is not a valid env-var name"
                return 1
            fi
        fi
    done
}

@test "requires_secret values look like env-var names" {
    for f in "$CATALOG_DIR"/*.yaml; do
        check_secret_names "$f"
    done
}

# ── entry is valid YAML ────────────────────────────────────────────────────

check_entry_yaml() {
    local file="$1"
    local list_key
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".${list_key}[$i].name" "$file")
        entry=$(yq ".${list_key}[$i].entry" "$file")
        if ! echo "$entry" | yq '.' >/dev/null 2>&1; then
            echo "Item $name in $file has entry that is not valid YAML"
            return 1
        fi
    done
}

@test "all catalog item entries are valid YAML" {
    for f in "$CATALOG_DIR"/*.yaml; do
        check_entry_yaml "$f"
    done
}

# ── files paths exist ──────────────────────────────────────────────────────

check_files_paths() {
    local file="$1"
    local list_key
    list_key=$(yq 'keys | .[0]' "$file")
    local count
    count=$(yq ".${list_key} | length" "$file")
    for ((i = 0; i < count; i++)); do
        local name files_count
        name=$(yq ".${list_key}[$i].name" "$file")
        files_count=$(yq ".${list_key}[$i].files | length" "$file" 2>/dev/null || echo 0)
        if [[ "$files_count" == "null" ]]; then
            files_count=0
        fi
        for ((j = 0; j < files_count; j++)); do
            local fpath
            fpath=$(yq ".${list_key}[$i].files[$j]" "$file")
            if [[ "$fpath" != "null" && ! -f "$REPO_ROOT/$fpath" ]]; then
                echo "Item $name in $file references files path '$fpath' which does not exist in repo"
                return 1
            fi
        done
    done
}

@test "all files paths in catalog items exist in the repo" {
    for f in "$CATALOG_DIR"/*.yaml; do
        check_files_paths "$f"
    done
}

# ── No personal content in catalog files ───────────────────────────────────

@test "no personal owner string in catalog files" {
    local _pat="paul"
    _pat+="nsorensen"
    local result
    result=$(grep -rl "$_pat" "$CATALOG_DIR" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: found personal owner string in: $result"
        return 1
    fi
}

@test "no personal flair pattern in catalog files" {
    local _pat="cheese"
    _pat+="-flair"
    local result
    result=$(grep -rl "$_pat" "$CATALOG_DIR" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: found personal flair pattern in: $result"
        return 1
    fi
}

@test "no live API key values in catalog files" {
    # Check for actual key patterns, not variable names
    local result
    result=$(grep -rE "ctx7sk-|tvly-dev-[A-Za-z0-9]|0b1d[a-f0-9]{30}" "$CATALOG_DIR" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: found live API key pattern in catalog: $result"
        return 1
    fi
}

# ── Count checks (at least one item per file) ──────────────────────────────

@test "mcp.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/mcp.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/mcp.yaml")
    (( count >= 1 ))
}

@test "hooks.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/hooks.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/hooks.yaml")
    (( count >= 1 ))
}

@test "skills.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/skills.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/skills.yaml")
    (( count >= 1 ))
}

@test "plugins.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/plugins.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/plugins.yaml")
    (( count >= 1 ))
}

@test "packages.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/packages.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/packages.yaml")
    (( count >= 1 ))
}

@test "zsh.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/zsh.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/zsh.yaml")
    (( count >= 1 ))
}

@test "mac-extras.yaml has at least 1 item" {
    local list_key count
    list_key=$(yq 'keys | .[0]' "$CATALOG_DIR/mac-extras.yaml")
    count=$(yq ".${list_key} | length" "$CATALOG_DIR/mac-extras.yaml")
    (( count >= 1 ))
}
