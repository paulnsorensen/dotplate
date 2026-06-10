#!/usr/bin/env bats
# Template hygiene guard — verifies no personal content leaked into dotplate.
#
# WHY each assertion matters:
#   - personal identifiers (paulnsorensen, real email) would make the template
#     non-generic and require every adopter to hunt-and-replace them
#   - cheese-flair strings belong to the personal stratum; they have no place
#     in a public template repo
#   - rtk config is a personal tool dependency; adopters should not inherit it
#   - .env files must never be committed; only .env.example with placeholders
#   - key-material patterns (API key shapes, sk-/tvly- prefixes) must never land
#   - personal plist exports and background images must be stripped
#   - the personal password phrase must not appear

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[0]:-$0}}")/.." && pwd)"

# Helper: grep entire repo tree for a pattern, fail if found.
# Note: BATS_TEST_FILENAME is set by bats and points to the .bats file reliably.
# Uses find+xargs to stay strictly within REPO_ROOT, excluding .git and this
# hygiene test file (which necessarily contains the banned strings as patterns).
assert_not_in_repo() {
    local pattern="$1"
    local description="$2"
    local this_file="$REPO_ROOT/tests/template-hygiene.bats"
    local result
    # find lists only files we own; grep never wanders outside
    result=$(find "$REPO_ROOT" \
             \( -name "*.sh" -o -name "*.bash" -o -name "*.yaml" \
                -o -name "*.yml" -o -name "*.toml" -o -name "*.json" \
                -o -name "*.tmpl" -o -name "*.md" -o -name "*.txt" \
                -o -name "*.bats" -o -name "*.zsh" -o -name "zshrc" \) \
             -not -path "$REPO_ROOT/.git/*" \
             -not -path "$this_file" \
             2>/dev/null \
             | xargs grep -l "$pattern" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: found '$description' in:"
        echo "$result"
        return 1
    fi
    return 0
}

# Helper: check for a literal filename anywhere in the tree
assert_file_not_present() {
    local filename="$1"
    local result
    result=$(find "$REPO_ROOT" -name "$filename" \
             -not -path "$REPO_ROOT/.git/*" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: file '$filename' found at:"
        echo "$result"
        return 1
    fi
    return 0
}

# ── Personal identifiers ──────────────────────────────────────────────────────

@test "no 'paulnsorensen' in any tracked file" {
    assert_not_in_repo "paulnsorensen" "paulnsorensen"
}

@test "no 'Paul Sorensen' in any tracked file" {
    assert_not_in_repo "Paul Sorensen" "Paul Sorensen"
}

@test "no personal email address in any tracked file" {
    assert_not_in_repo "paulnsorensen@gmail\.com" "paulnsorensen@gmail.com"
}

# ── Cheese flair (personal stratum) ──────────────────────────────────────────

@test "no 'cheese-flair' string in any tracked file" {
    assert_not_in_repo "cheese-flair" "cheese-flair"
}

@test "no 'Cheese Lord' string in any tracked file" {
    assert_not_in_repo "Cheese Lord" "Cheese Lord"
}

# ── RTK (personal tool) ───────────────────────────────────────────────────────

@test "no rtk-rewrite.json hook config" {
    assert_file_not_present "rtk-rewrite.json"
}

@test "no rtk cargo install entry in tracked files" {
    # rtk as a git-sourced cargo package from rtk-ai/rtk is personal config
    assert_not_in_repo "rtk-ai/rtk" "rtk-ai/rtk"
}

# ── Secrets and .env files ────────────────────────────────────────────────────

@test "no .env file committed (only .env.example allowed)" {
    local result
    result=$(find "$REPO_ROOT" -name ".env" \
             -not -name ".env.example" \
             -not -name ".env.*" \
             -not -path "$REPO_ROOT/.git/*" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: .env file committed at:"
        echo "$result"
        return 1
    fi
}

@test ".env.example exists with placeholder values (no real keys)" {
    local envfile="$REPO_ROOT/.env.example"
    [[ -f "$envfile" ]] || { echo "FAIL: .env.example not found"; return 1; }
    # Must not contain any real key patterns: ctx7sk-, tvly-dev-, 0b1d (todoist token prefix)
    if grep -qE "ctx7sk-|tvly-dev-[A-Za-z0-9]|0b1d[a-f0-9]{30}" "$envfile" 2>/dev/null; then
        echo "FAIL: .env.example contains what looks like a real API key"
        return 1
    fi
}

# ── Key material patterns ─────────────────────────────────────────────────────

@test "no 'sk-' prefixed strings (OpenAI/Anthropic key pattern)" {
    # Matches sk-<alphanum 20+> — the common API key shape
    local result
    result=$(grep -rE "sk-[A-Za-z0-9]{20,}" "$REPO_ROOT" \
             --include="*.sh" --include="*.bash" \
             --include="*.yaml" --include="*.yml" \
             --include="*.toml" --include="*.json" \
             --include="*.tmpl" --include="*.md" \
             --include="*.txt" --include="*.bats" \
             --include="*.env" --include="*.env.example" \
             -l 2>/dev/null \
             | grep -v "^$REPO_ROOT/\.git/" || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: sk-prefixed key pattern found in:"
        echo "$result"
        return 1
    fi
}

@test "no 'tvly-' prefixed strings (Tavily key pattern)" {
    local result
    result=$(grep -rE "tvly-[A-Za-z0-9]{10,}" "$REPO_ROOT" \
             --include="*.sh" --include="*.bash" \
             --include="*.yaml" --include="*.yml" \
             --include="*.toml" --include="*.json" \
             --include="*.tmpl" --include="*.md" \
             --include="*.txt" --include="*.bats" \
             --include="*.env" --include="*.env.example" \
             -l 2>/dev/null \
             | grep -v "^$REPO_ROOT/\.git/" || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: tvly-prefixed key pattern found in:"
        echo "$result"
        return 1
    fi
}

# ── Personal plists / images ──────────────────────────────────────────────────

@test "no iterm2 personal plist files committed" {
    assert_file_not_present "com.googlecode.iterm2.plist"
    assert_file_not_present "iterm2.base.plist"
}

@test "no iterm2 personal dynamic.yaml committed" {
    local result
    result=$(find "$REPO_ROOT" -name "dynamic.yaml" \
             -not -path "$REPO_ROOT/.git/*" 2>/dev/null || true)
    # dynamic.yaml is personal if it references i_know_how_to_make_ducks
    for f in $result; do
        if grep -q "i_know_how_to_make_ducks" "$f" 2>/dev/null; then
            echo "FAIL: personal dynamic.yaml (duck reference) found at $f"
            return 1
        fi
    done
}

@test "no 'i_know_how_to_make_ducks' personal password phrase" {
    assert_not_in_repo "i_know_how_to_make_ducks" "i_know_how_to_make_ducks"
}

@test "no .plist files from iterm2 personal exports" {
    local result
    result=$(find "$REPO_ROOT/iterm2" -name "*.plist" \
             -not -path "$REPO_ROOT/.git/*" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo "FAIL: plist files found in iterm2/:"
        echo "$result"
        return 1
    fi
}

# ── Cargo/personal project references ────────────────────────────────────────

@test "no milknado personal project reference" {
    assert_not_in_repo "paulnsorensen/milknado" "paulnsorensen/milknado"
}

@test "no 'cheese-grok' plugin directory name in any tracked file" {
    # cheese-grok is a personal plugin name; the directory was renamed to repo-hooks
    assert_not_in_repo "cheese-grok" "cheese-grok"
}
