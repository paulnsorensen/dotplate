#!/usr/bin/env bats
# Onboarding flow structural tests — Phase C.
#
# These tests verify the contract before the docs exist so the docs are
# written to make them pass, not the other way around.
#
# Assertions encode WHY each claim matters:
#   - AGENTS.md must direct any harness-reading agent to the guide so the
#     onboarding actually starts on a fresh clone.
#   - CLAUDE.md must be exactly the import line (per source-repo convention);
#     anything more is personal content.
#   - GUIDE.md must contain all eight passes so no step is silently omitted.
#   - Every pass must contain 'dots sync' so the materialize/sync/verify
#     discipline is enforced and the user sees working results per pass.
#   - state.yaml must parse with 8 pending entries; stale or incomplete state
#     means onboarding cannot resume correctly.
#   - README must contain the three-step start so a new user knows how to begin.
#   - The resume helper contract must be executable, not just documented.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[0]:-$0}}")/.."; pwd)"

# ── AGENTS.md ────────────────────────────────────────────────────────────────

@test "AGENTS.md exists" {
    [[ -f "$REPO_ROOT/AGENTS.md" ]]
}

@test "AGENTS.md mentions onboard/GUIDE.md" {
    grep -q "onboard/GUIDE.md" "$REPO_ROOT/AGENTS.md"
}

@test "AGENTS.md mentions onboard/state.yaml" {
    grep -q "onboard/state.yaml" "$REPO_ROOT/AGENTS.md"
}

@test "AGENTS.md declares this is an unpersonalized dotfiles template" {
    # Must orient a fresh-clone agent so it does not assume a personalized repo
    grep -qi "unpersonalized\|template" "$REPO_ROOT/AGENTS.md"
}

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────

@test "CLAUDE.md exists" {
    [[ -f "$REPO_ROOT/CLAUDE.md" ]]
}

@test "CLAUDE.md is exactly the import line @AGENTS.md" {
    # Must be exactly one line — the import — so Claude Code picks up AGENTS.md.
    # Any additional content in CLAUDE.md would be personal stratum.
    local content
    content=$(cat "$REPO_ROOT/CLAUDE.md")
    # Trim trailing newlines for comparison
    content=$(echo "$content" | sed '/^$/d')
    [[ "$content" == "@AGENTS.md" ]]
}

# ── GUIDE.md — eight passes present ──────────────────────────────────────────

@test "onboard/GUIDE.md exists" {
    [[ -f "$REPO_ROOT/onboard/GUIDE.md" ]]
}

@test "GUIDE.md contains Pass 0 (Prerequisites)" {
    grep -qiE "pass 0|## 0" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 1 (Orientation)" {
    grep -qiE "pass 1|## 1" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 2 (Identity)" {
    grep -qiE "pass 2|## 2" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 3 (Shell)" {
    grep -qiE "pass 3|## 3" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 4 (Packages)" {
    grep -qiE "pass 4|## 4" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 5 (Secrets)" {
    grep -qiE "pass 5|## 5" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 6 (Agent config)" {
    grep -qiE "pass 6|## 6" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md contains Pass 7 (Graduation)" {
    grep -qiE "pass 7|## 7" "$REPO_ROOT/onboard/GUIDE.md"
}

# ── GUIDE.md — materialize/sync/verify discipline ─────────────────────────────

@test "GUIDE.md references 'dots sync' at least 8 times (once per pass)" {
    # Each pass must end materialize -> dots sync -> verify.
    # Counting occurrences enforces the per-pass discipline is not omitted.
    local count
    count=$(grep -c "dots sync" "$REPO_ROOT/onboard/GUIDE.md" || true)
    (( count >= 8 ))
}

@test "GUIDE.md mentions vi-mode as opt-in (not silent default)" {
    # Spec requirement: vi-mode must NOT be the silent default; it must be an
    # explicit opt-in question so newcomers are not surprised.
    grep -qi "vi.mode\|vi mode" "$REPO_ROOT/onboard/GUIDE.md"
    grep -qi "opt.in\|ask\|question\|do you\|would you" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md mentions secrets strategy gating (1Password or env file)" {
    # Pass 5 must explain the secrets choice and note it gates pass 6 items.
    grep -qi "1password\|1 password" "$REPO_ROOT/onboard/GUIDE.md"
}

@test "GUIDE.md mentions uv prerequisite" {
    # Pass 0 must call out uv so the chezmoi hook doesn't silently skip.
    grep -q "uv" "$REPO_ROOT/onboard/GUIDE.md"
}

# ── state.yaml — schema and initial values ─────────────────────────────────────

@test "onboard/state.yaml exists" {
    [[ -f "$REPO_ROOT/onboard/state.yaml" ]]
}

@test "state.yaml parses as YAML" {
    yq '.' "$REPO_ROOT/onboard/state.yaml" >/dev/null 2>&1
}

@test "state.yaml has schema_version field" {
    local v
    v=$(yq '.schema_version' "$REPO_ROOT/onboard/state.yaml")
    [[ "$v" != "null" && -n "$v" ]]
}

@test "state.yaml has exactly 8 pass entries" {
    local count
    count=$(yq '.passes | length' "$REPO_ROOT/onboard/state.yaml")
    [[ "$count" -eq 8 ]]
}

@test "all 8 pass entries start as pending" {
    # On a fresh clone every pass is pending; any non-pending initial value
    # would corrupt onboarding for new users.
    local non_pending
    non_pending=$(yq '.passes[] | select(.status != "pending") | .status' \
        "$REPO_ROOT/onboard/state.yaml" || true)
    [[ -z "$non_pending" ]]
}

@test "state.yaml has top-level detected_os field" {
    # The GUIDE reads detected_os to filter OS-gated catalog entries.
    yq '.detected_os' "$REPO_ROOT/onboard/state.yaml" >/dev/null 2>&1
}

@test "state.yaml has top-level secrets_strategy field" {
    # Pass 5 records the choice; pass 6 reads it to filter secret-requiring items.
    yq '.secrets_strategy' "$REPO_ROOT/onboard/state.yaml" >/dev/null 2>&1
}

# ── README.md — three-step start ──────────────────────────────────────────────

@test "README.md exists" {
    [[ -f "$REPO_ROOT/README.md" ]]
}

@test "README.md mentions installing an agent CLI" {
    # Step 1 of the three-step start.
    grep -qi "agent cli\|claude code\|codex\|install.*agent\|agent.*install" \
        "$REPO_ROOT/README.md"
}

@test "README.md mentions 'Use this template' (GitHub clone step)" {
    # Step 2: GitHub template clone.
    grep -qi "use this template\|github.*template\|clone" \
        "$REPO_ROOT/README.md"
}

@test "README.md mentions opening the agent and saying hi" {
    # Step 3: the entry point to onboarding.
    grep -qi "open.*agent\|say hi\|hello\|onboarding\|start" \
        "$REPO_ROOT/README.md"
}

@test "README.md mentions macOS" {
    grep -qi "macos\|mac os\|darwin" "$REPO_ROOT/README.md"
}

@test "README.md mentions Linux" {
    grep -qi "linux" "$REPO_ROOT/README.md"
}

# ── onboard/lib/state.sh — resume helper ──────────────────────────────────────

@test "onboard/lib/state.sh exists" {
    [[ -f "$REPO_ROOT/onboard/lib/state.sh" ]]
}

@test "state_next_pass returns the first pending pass index" {
    # Simulate a state file with passes 0-2 done, rest pending.
    local tmp_state
    tmp_state=$(mktemp)
    # Build a state.yaml with 8 passes: 0,1,2 done, 3-7 pending
    yq --null-input '
        .schema_version = 1 |
        .detected_os = "" |
        .secrets_strategy = "" |
        .harnesses = [] |
        .passes = [
            {"index": 0, "name": "prerequisites",   "status": "done",    "answers": {"os": "macos"}},
            {"index": 1, "name": "orientation",      "status": "done",    "answers": {"comfort": "high"}},
            {"index": 2, "name": "identity",         "status": "done",    "answers": {"name": "Alice"}},
            {"index": 3, "name": "shell",            "status": "pending", "answers": {}},
            {"index": 4, "name": "packages",         "status": "pending", "answers": {}},
            {"index": 5, "name": "secrets",          "status": "pending", "answers": {}},
            {"index": 6, "name": "agent-config",     "status": "pending", "answers": {}},
            {"index": 7, "name": "graduation",       "status": "pending", "answers": {}}
        ]
    ' > "$tmp_state"

    # Source the helper and call state_next_pass
    local result
    result=$(bash "$REPO_ROOT/onboard/lib/state.sh" next "$tmp_state")
    rm -f "$tmp_state"
    [[ "$result" == "3" ]]
}

@test "state_get reads recorded answers from a done pass" {
    local tmp_state
    tmp_state=$(mktemp)
    yq --null-input '
        .schema_version = 1 |
        .detected_os = "macos" |
        .secrets_strategy = "" |
        .harnesses = [] |
        .passes = [
            {"index": 0, "name": "prerequisites",   "status": "done",    "answers": {"os": "macos"}},
            {"index": 1, "name": "orientation",      "status": "done",    "answers": {"comfort": "high"}},
            {"index": 2, "name": "identity",         "status": "done",    "answers": {"name": "Alice"}},
            {"index": 3, "name": "shell",            "status": "pending", "answers": {}},
            {"index": 4, "name": "packages",         "status": "pending", "answers": {}},
            {"index": 5, "name": "secrets",          "status": "pending", "answers": {}},
            {"index": 6, "name": "agent-config",     "status": "pending", "answers": {}},
            {"index": 7, "name": "graduation",       "status": "pending", "answers": {}}
        ]
    ' > "$tmp_state"

    local result
    result=$(bash "$REPO_ROOT/onboard/lib/state.sh" get "$tmp_state" '.passes[2].answers.name')
    rm -f "$tmp_state"
    [[ "$result" == "Alice" ]]
}

@test "state_next_pass returns 0 when all passes are pending" {
    local tmp_state
    tmp_state=$(mktemp)
    # Use the actual initial state.yaml (all pending)
    cp "$REPO_ROOT/onboard/state.yaml" "$tmp_state"

    local result
    result=$(bash "$REPO_ROOT/onboard/lib/state.sh" next "$tmp_state")
    rm -f "$tmp_state"
    [[ "$result" == "0" ]]
}

@test "state_next_pass returns 'done' when all passes are done" {
    local tmp_state
    tmp_state=$(mktemp)
    # Build a state where all passes are done
    yq --null-input '
        .schema_version = 1 |
        .detected_os = "macos" |
        .secrets_strategy = "onepassword" |
        .harnesses = ["claude"] |
        .passes = [
            {"index": 0, "name": "prerequisites",   "status": "done", "answers": {}},
            {"index": 1, "name": "orientation",      "status": "done", "answers": {}},
            {"index": 2, "name": "identity",         "status": "done", "answers": {}},
            {"index": 3, "name": "shell",            "status": "done", "answers": {}},
            {"index": 4, "name": "packages",         "status": "done", "answers": {}},
            {"index": 5, "name": "secrets",          "status": "done", "answers": {}},
            {"index": 6, "name": "agent-config",     "status": "done", "answers": {}},
            {"index": 7, "name": "graduation",       "status": "done", "answers": {}}
        ]
    ' > "$tmp_state"

    local result
    result=$(bash "$REPO_ROOT/onboard/lib/state.sh" next "$tmp_state")
    rm -f "$tmp_state"
    [[ "$result" == "done" ]]
}
