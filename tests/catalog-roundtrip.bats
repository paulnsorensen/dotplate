#!/usr/bin/env bats
# Catalog round-trip tests.
# For every item in onboard/catalog/{mcp,hooks,plugins,skills}.yaml:
#   - append its `entry` verbatim to a temp copy of the corresponding live registry
#   - verify the registry still parses as YAML
# For packages.yaml:
#   - validate entry YAML shape (source/platform/etc. fields are recognised by packages/sync.sh)
#
# WHY: catalog entries are copied verbatim into live registries on acceptance.
# A malformed entry or schema mismatch would silently break `dots sync` for the adopter.

load test_helper

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[0]:-$0}}")/.."; pwd)"
CATALOG_DIR="$REPO_ROOT/onboard/catalog"

# ─── helpers ────────────────────────────────────────────────────────────────

# Append $entry_yaml (a block-scalar string) under the top-level mapping key $key
# in the registry at $registry_file, writing to $out_file.
#
# Handles the case where the registry has `key: {}` (empty inline dict) —
# replaces it with `key:` so block-mapping children can follow.
append_entry_to_registry() {
    local registry_file="$1" key="$2" entry_yaml="$3" out_file="$4"
    # Convert `key: {}` to `key:` so block entries can be appended.
    sed "s/^${key}: {}$/${key}:/" "$registry_file" > "$out_file"
    # Indent each line of the entry by 2 spaces (one level under the key).
    local indented
    indented=$(printf '%s' "$entry_yaml" | awk '{print "  " $0}')
    printf '%s\n' "$indented" >> "$out_file"
}

# ─── MCP round-trip ─────────────────────────────────────────────────────────

@test "all mcp catalog entries append to live registry without breaking YAML" {
    local count
    count=$(yq '.mcps | length' "$CATALOG_DIR/mcp.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".mcps[$i].name" "$CATALOG_DIR/mcp.yaml")
        entry=$(yq ".mcps[$i].entry" "$CATALOG_DIR/mcp.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/agents/mcp/registry.yaml" "mcps" "$entry" "$tmp"
        if ! yq '.' "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            echo "FAIL: mcp entry '$name' produces invalid YAML in registry" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

@test "all mcp catalog entries have a command field" {
    local count
    count=$(yq '.mcps | length' "$CATALOG_DIR/mcp.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".mcps[$i].name" "$CATALOG_DIR/mcp.yaml")
        entry=$(yq ".mcps[$i].entry" "$CATALOG_DIR/mcp.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/agents/mcp/registry.yaml" "mcps" "$entry" "$tmp"

        # The last key added must have a command field.
        local mcp_key
        mcp_key=$(yq '.mcps | keys | .[-1]' "$tmp" 2>/dev/null)
        if [[ -z "$mcp_key" || "$mcp_key" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: mcp entry '$name' added no key to registry" >&2
            return 1
        fi
        local cmd
        cmd=$(yq ".mcps[\"$mcp_key\"].command" "$tmp" 2>/dev/null)
        if [[ -z "$cmd" || "$cmd" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: mcp entry '$name' (key: $mcp_key) is missing 'command' field" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

# ─── hooks round-trip ───────────────────────────────────────────────────────

@test "all hooks catalog entries append to live registry without breaking YAML" {
    local count
    count=$(yq '.hooks | length' "$CATALOG_DIR/hooks.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".hooks[$i].name" "$CATALOG_DIR/hooks.yaml")
        entry=$(yq ".hooks[$i].entry" "$CATALOG_DIR/hooks.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/agents/hooks/registry.yaml" "hooks" "$entry" "$tmp"
        if ! yq '.' "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            echo "FAIL: hooks entry '$name' produces invalid YAML in registry" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

@test "all hooks catalog entries have event and command/script fields" {
    local count
    count=$(yq '.hooks | length' "$CATALOG_DIR/hooks.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".hooks[$i].name" "$CATALOG_DIR/hooks.yaml")
        entry=$(yq ".hooks[$i].entry" "$CATALOG_DIR/hooks.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/agents/hooks/registry.yaml" "hooks" "$entry" "$tmp"

        # Count pre-existing hooks to identify new ones.
        local pre_count
        pre_count=$(yq '.hooks | length' "$REPO_ROOT/agents/hooks/registry.yaml" 2>/dev/null)
        local post_count
        post_count=$(yq '.hooks | length' "$tmp" 2>/dev/null)
        if [[ "$post_count" -le "$pre_count" ]]; then
            rm -f "$tmp"
            echo "FAIL: hooks entry '$name' added no keys to registry" >&2
            return 1
        fi

        # Validate each newly-added hook key.
        local hook_key
        local j=0
        while IFS= read -r hook_key; do
            ((j++)) || true
            [[ $j -le $pre_count ]] && continue  # skip pre-existing
            local ev has_cmd has_script
            ev=$(yq ".hooks[\"$hook_key\"].event" "$tmp" 2>/dev/null)
            has_cmd=$(yq ".hooks[\"$hook_key\"].command" "$tmp" 2>/dev/null)
            has_script=$(yq ".hooks[\"$hook_key\"].script" "$tmp" 2>/dev/null)
            if [[ -z "$ev" || "$ev" == "null" ]]; then
                rm -f "$tmp"
                echo "FAIL: hooks entry '$name' key '$hook_key' missing 'event'" >&2
                return 1
            fi
            if [[ ("$has_cmd" == "null" || -z "$has_cmd") && ("$has_script" == "null" || -z "$has_script") ]]; then
                rm -f "$tmp"
                echo "FAIL: hooks entry '$name' key '$hook_key' has neither 'command' nor 'script'" >&2
                return 1
            fi
        done < <(yq '.hooks | keys | .[]' "$tmp" 2>/dev/null)
        rm -f "$tmp"
    done
}

# ─── plugins round-trip ─────────────────────────────────────────────────────

@test "all plugins catalog entries append to live registry without breaking YAML" {
    local count
    count=$(yq '.plugins | length' "$CATALOG_DIR/plugins.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".plugins[$i].name" "$CATALOG_DIR/plugins.yaml")
        entry=$(yq ".plugins[$i].entry" "$CATALOG_DIR/plugins.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/claude/plugins/registry.yaml" "plugins" "$entry" "$tmp"
        if ! yq '.' "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            echo "FAIL: plugins entry '$name' produces invalid YAML in registry" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

@test "all plugins catalog entries have a description field" {
    local count
    count=$(yq '.plugins | length' "$CATALOG_DIR/plugins.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".plugins[$i].name" "$CATALOG_DIR/plugins.yaml")
        entry=$(yq ".plugins[$i].entry" "$CATALOG_DIR/plugins.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/claude/plugins/registry.yaml" "plugins" "$entry" "$tmp"
        local plugin_key
        plugin_key=$(yq '.plugins | keys | .[-1]' "$tmp" 2>/dev/null)
        if [[ -z "$plugin_key" || "$plugin_key" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: plugins entry '$name' added no key to registry" >&2
            return 1
        fi
        local desc
        desc=$(yq ".plugins[\"$plugin_key\"].description" "$tmp" 2>/dev/null)
        if [[ -z "$desc" || "$desc" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: plugins entry '$name' (key: $plugin_key) is missing 'description'" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

# ─── skills round-trip ──────────────────────────────────────────────────────

@test "all skills catalog entries append to live registry without breaking YAML" {
    local count
    count=$(yq '.skills | length' "$CATALOG_DIR/skills.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".skills[$i].name" "$CATALOG_DIR/skills.yaml")
        entry=$(yq ".skills[$i].entry" "$CATALOG_DIR/skills.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/skills/_registry.yaml" "sources" "$entry" "$tmp"
        if ! yq '.' "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            echo "FAIL: skills entry '$name' produces invalid YAML in registry" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

@test "all skills catalog entries have a description field" {
    local count
    count=$(yq '.skills | length' "$CATALOG_DIR/skills.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".skills[$i].name" "$CATALOG_DIR/skills.yaml")
        entry=$(yq ".skills[$i].entry" "$CATALOG_DIR/skills.yaml")

        local tmp; tmp=$(mktemp)
        append_entry_to_registry "$REPO_ROOT/skills/_registry.yaml" "sources" "$entry" "$tmp"
        local source_key
        source_key=$(yq '.sources | keys | .[-1]' "$tmp" 2>/dev/null)
        if [[ -z "$source_key" || "$source_key" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: skills entry '$name' added no key to registry" >&2
            return 1
        fi
        local desc
        desc=$(yq ".sources[\"$source_key\"].description" "$tmp" 2>/dev/null)
        if [[ -z "$desc" || "$desc" == "null" ]]; then
            rm -f "$tmp"
            echo "FAIL: skills entry '$name' (key: $source_key) is missing 'description'" >&2
            return 1
        fi
        rm -f "$tmp"
    done
}

# ─── packages schema round-trip ─────────────────────────────────────────────
# Validate that each catalog packages entry is a valid packages.yaml stanza.
# Known source types: brew (default), tap, cask, cargo, npm, uv, gh-extension.
# Known platform values: mac, linux.
# We do NOT install any packages — schema validation only.

@test "all packages catalog entries produce valid packages.yaml schema" {
    local valid_sources="brew tap cask cargo npm uv gh-extension"
    local count
    count=$(yq '.packages | length' "$CATALOG_DIR/packages.yaml")
    for ((i = 0; i < count; i++)); do
        local name entry
        name=$(yq ".packages[$i].name" "$CATALOG_DIR/packages.yaml")
        entry=$(yq ".packages[$i].entry" "$CATALOG_DIR/packages.yaml")

        # Append entry to a temp copy of packages.yaml and verify it parses.
        local tmp; tmp=$(mktemp)
        cp "$REPO_ROOT/packages/packages.yaml" "$tmp"
        local indented
        indented=$(printf '%s' "$entry" | awk '{print "  " $0}')
        printf '%s\n' "$indented" >> "$tmp"

        if ! yq '.' "$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            echo "FAIL: packages entry '$name' produces invalid YAML" >&2
            return 1
        fi

        # Verify source values are from the known set.
        local sources
        sources=$(yq -r '.packages[] | select(kind == "map") | to_entries[0] | .value.source // "brew"' "$tmp" 2>/dev/null || true)
        while IFS= read -r src; do
            [[ -z "$src" ]] && continue
            local found=false
            for vs in $valid_sources; do
                [[ "$src" == "$vs" ]] && found=true && break
            done
            if ! $found; then
                rm -f "$tmp"
                echo "FAIL: packages entry '$name' has unrecognized source '$src'" >&2
                return 1
            fi
        done <<< "$sources"

        # Verify platform values are mac or linux if present.
        local platforms
        platforms=$(yq -r '.packages[] | select(kind == "map") | to_entries[0] | .value.platform // empty' "$tmp" 2>/dev/null || true)
        while IFS= read -r plat; do
            [[ -z "$plat" ]] && continue
            if [[ "$plat" != "mac" && "$plat" != "linux" ]]; then
                rm -f "$tmp"
                echo "FAIL: packages entry '$name' has unrecognized platform '$plat'" >&2
                return 1
            fi
        done <<< "$platforms"

        rm -f "$tmp"
    done
}

# ─── files paths exist ─────────────────────────────────────────────────────────────

@test "catalog entries with files have all listed assets present" {
    local catalog_files
    catalog_files=("$CATALOG_DIR"/*.yaml)
    for cf in "${catalog_files[@]}"; do
        local list_key count
        list_key=$(yq 'keys | .[0]' "$cf")
        count=$(yq ".${list_key} | length" "$cf")
        for ((i = 0; i < count; i++)); do
            local name files_count
            name=$(yq ".${list_key}[$i].name" "$cf")
            files_count=$(yq ".${list_key}[$i].files | length" "$cf" 2>/dev/null)
            # yq returns 0 for missing/null length
            [[ -z "$files_count" || "$files_count" == "null" ]] && files_count=0
            for ((j = 0; j < files_count; j++)); do
                local fpath
                fpath=$(yq ".${list_key}[$i].files[$j]" "$cf")
                if [[ "$fpath" != "null" && ! -f "$REPO_ROOT/$fpath" ]]; then
                    echo "FAIL: catalog item '$name' references '$fpath' which does not exist" >&2
                    return 1
                fi
            done
        done
    done
}

# ─── null-entry rejection ────────────────────────────────────────────────────────────

@test "catalog entry with null entry field produces detectable corruption, not silent append" {
    # WHY: when a catalog item's `entry` is null/missing, yq returns the string
    # "null". Appending that literal to a registry produces a document with a
    # bare 'null' scalar under the top-level key, which breaks any subsequent
    # yq query that expects a mapping. This test asserts the corruption is
    # detectable (the registry loses its mapping structure) so a walker can
    # check `[[ "$entry" == "null" || -z "$entry" ]]` and skip/fail rather
    # than silently poisoning the registry.
    local tmp_catalog tmp_out
    tmp_catalog=$(mktemp)
    tmp_out=$(mktemp)

    # Synthetic malformed catalog: entry is explicitly null.
    cat > "$tmp_catalog" <<'YAML'
mcps:
  - name: broken-null-entry
    pitch: This entry has no content
    entry: null
YAML

    # yq must return 'null' for a null entry field.
    local entry
    entry=$(yq '.mcps[0].entry' "$tmp_catalog")
    [[ "$entry" == "null" ]] || {
        rm -f "$tmp_catalog" "$tmp_out"
        echo "FAIL: expected yq to return 'null' for null entry field, got: $entry" >&2
        return 1
    }

    # Appending 'null' (the string) to a registry breaks the mapping structure:
    # the mcps key's value becomes a bare 'null' scalar, so
    # `yq '.mcps | type'` is no longer 'map'.
    cp "$REPO_ROOT/agents/mcp/registry.yaml" "$tmp_out"
    sed 's/^mcps: {}$/mcps:/' "$tmp_out" > "$tmp_out.mod" && mv "$tmp_out.mod" "$tmp_out"
    printf '  null\n' >> "$tmp_out"
    local mcps_type
    mcps_type=$(yq '.mcps | type' "$tmp_out" 2>/dev/null || echo 'error')
    # After appending 'null', the mcps type must NOT be '!!map' — confirming
    # that a null entry corrupts the registry in a detectable way.
    [[ "$mcps_type" == '!!map' ]] && {
        rm -f "$tmp_catalog" "$tmp_out"
        echo "FAIL: expected registry to be corrupted by null append (mcps should lose map type)" >&2
        return 1
    }

    rm -f "$tmp_catalog" "$tmp_out"
}
