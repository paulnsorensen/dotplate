#!/usr/bin/env bash
# End-to-end onboarding dry-run.
#
# Simulates all 8 passes of onboard/GUIDE.md with canned answers.
# Runs entirely in a temp copy of the repo — never touches $HOME.
# Validates the state machine, resumability, and graduation output.
#
# WHY: the onboarding guide is the primary adopter experience. A regression
# in state tracking or graduation silently breaks first-run for every new user.
#
# Exit 0 = pass, exit 1 = fail.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Copy the dotplate repo into $TMP so we never mutate $HOME or the real repo.
DOTSRC="$TMP/dotplate"
cp -r "$REPO_ROOT/" "$DOTSRC/"

# Fake $HOME so dots sync / chezmoi never writes to the real home.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME"

DOTSRC="$TMP/dotplate"  # the mutable copy
STATE="$DOTSRC/onboard/state.yaml"

# Helper: set a yq value in the state file.
state_set() {
    local path="$1" val="$2"
    yq -i "$path = \"$val\"" "$STATE"
}

# Helper: mark a pass done.
pass_done() {
    local n="$1"
    yq -i ".passes[$n].status = \"done\"" "$STATE"
}

# Helper: record an answer for a pass.
pass_answer() {
    local n="$1" key="$2" val="$3"
    yq -i ".passes[$n].answers.$key = \"$val\"" "$STATE"
}

echo "=== e2e onboarding dry-run ==="
echo "Working copy: $DOTSRC"
echo

# ─── Verify initial state ─────────────────────────────────────────────────────────────

next=$(bash "$DOTSRC/onboard/lib/state.sh" next "$STATE")
[[ "$next" == "0" ]] || fail "Expected first pending pass to be 0, got: $next"
pass "Initial state has pass 0 as first pending"

# ─── AGENTS.md has the unpersonalized marker ─────────────────────────────────────

python3 -c "
import sys
with open('$DOTSRC/AGENTS.md') as f:
    content = f.read()
if 'unpersonalized' not in content:
    print('FAIL: AGENTS.md does not contain expected unpersonalized marker')
    sys.exit(1)
print('PASS: AGENTS.md has unpersonalized marker')
"

# ─── Pass 0: Prerequisites (simulated) ──────────────────────────────────────────────
echo "--- Pass 0: prerequisites ---"
# Detect OS without running linux-install or brew.
detected_os="macos"
[[ "$(uname -s)" == "Linux" ]] && detected_os="linux"
state_set ".detected_os" "$detected_os"
pass_done 0
next=$(bash "$DOTSRC/onboard/lib/state.sh" next "$STATE")
[[ "$next" == "1" ]] || fail "After pass 0 done, expected pass 1 next, got: $next"
pass "Pass 0 done — state machine advances to pass 1"

# ─── Pass 1: Orientation ───────────────────────────────────────────────────────────────
echo "--- Pass 1: orientation ---"
pass_answer 1 "comfort" "advanced"
pass_answer 1 "goals" "agent-ai-coding"
pass_answer 1 "machines" "2"
pass_done 1
next=$(bash "$DOTSRC/onboard/lib/state.sh" next "$STATE")
[[ "$next" == "2" ]] || fail "After pass 1 done, expected pass 2 next, got: $next"
pass "Pass 1 done"

# ─── Resumability test ──────────────────────────────────────────────────────────────
# Simulate interruption after pass 1 (passes 2-7 still pending).
# A re-read of state.yaml must still return pass 2 as next.
next_resume=$(bash "$DOTSRC/onboard/lib/state.sh" next "$STATE")
[[ "$next_resume" == "2" ]] || fail "Resumability: expected pass 2 after interruption, got: $next_resume"
pass "Resumability: re-reading state.yaml after interruption at pass 2 returns pass 2"

# ─── Pass 2: Identity ────────────────────────────────────────────────────────────────
echo "--- Pass 2: identity ---"
# Write identity into chezmoi/.chezmoi.toml.tmpl [data] section.
# The template already has a [data] block; we append to it.
# (In the real flow, the agent writes these values; here we simulate that.)
TOML_FILE="$DOTSRC/chezmoi/.chezmoi.toml.tmpl"
if python3 -c "
import re, sys
with open('$TOML_FILE') as f:
    content = f.read()
has_data = '[data]' in content
sys.exit(0 if has_data else 1)
"; then
    # Append to the existing [data] block via yq equivalent for TOML.
    # chezmoi.toml.tmpl uses Go template syntax; the [data] section holds
    # static values. We write a standalone .chezmoi.toml to the fake home
    # instead so chezmoi uses it without re-prompting.
    mkdir -p "$FAKE_HOME/.config/chezmoi"
    cat > "$FAKE_HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$DOTSRC/chezmoi"
[data]
  name  = "Test User"
  email = "test@example.com"
  editor = "vim"
EOF
    pass_answer 2 "name" "Test User"
    pass_answer 2 "email" "test@example.com"
    pass_answer 2 "editor" "vim"
    pass_done 2
    pass "Pass 2 done — identity written to fake home chezmoi config"
else
    fail "chezmoi/.chezmoi.toml.tmpl does not have a [data] section"
fi

# ─── Pass 3: Shell (skip — no zsh module writes needed for dry-run) ───────────────
echo "--- Pass 3: shell ---"
yq -i '.passes[3].answers.modules = []' "$STATE"
pass_done 3
pass "Pass 3 done (no shell modules — dry-run)"

# ─── Pass 4: Packages (skip — no installs in dry-run) ─────────────────────────
echo "--- Pass 4: packages ---"
yq -i '.passes[4].answers.packages = []' "$STATE"
pass_done 4
pass "Pass 4 done (no packages — dry-run)"

# ─── Pass 5: Secrets ────────────────────────────────────────────────────────────────
echo "--- Pass 5: secrets ---"
state_set ".secrets_strategy" "skip"
pass_done 5
pass "Pass 5 done (secrets strategy: skip)"

# ─── Pass 6: Agent config (skip catalog acceptance — dry-run) ──────────────────
echo "--- Pass 6: agent config ---"
# Simulate accepting zero catalog items (valid minimal run).
yq -i '.harnesses = ["claude"]' "$STATE"
pass_done 6
pass "Pass 6 done (no catalog items — dry-run)"

# ─── Pass 7: Graduation ──────────────────────────────────────────────────────────────
echo "--- Pass 7: graduation ---"
# Graduation: rewrite AGENTS.md to reflect personalization,
# move onboard/ to .onboard-archive/.
NAME="Test User"
EMAIL="test@example.com"

cat > "$DOTSRC/AGENTS.md" <<EOF
# dotplate — personalized dotfiles for $NAME

This repository has completed onboarding and is personalized for $NAME ($EMAIL).
The agent registries, shell modules, and packages have been configured.

## Quick reference
- \`dots sync\` — apply all config to this machine
- \`dots doctor\` — health check
- \`dots test\` — run the test suite
EOF

# Mark pass 7 done before archiving — the state file lives inside onboard/.
pass_done 7

# Archive the onboard/ directory.
mv "$DOTSRC/onboard" "$DOTSRC/.onboard-archive"

# The state file has moved; update STATE to point at the new location.
STATE="$DOTSRC/.onboard-archive/state.yaml"

pass "Pass 7 done — AGENTS.md rewritten, onboard/ archived"

# ─── Assertions ──────────────────────────────────────────────────────────────────
echo "--- Assertions ---"

# 1. state.yaml: all passes done.
still_pending=$(yq '.passes[] | select(.status == "pending") | .index' "$STATE" | wc -l | tr -d ' ')
[[ "$still_pending" -eq 0 ]] || fail "$still_pending pass(es) still pending in state.yaml after graduation"
pass "All 8 passes are done in state.yaml"

# 2. state.sh reports 'done'.
final=$(bash "$DOTSRC/.onboard-archive/lib/state.sh" next "$STATE")
[[ "$final" == "done" ]] || fail "state.sh next returned '$final' (expected 'done') after all passes complete"
pass "state.sh next returns 'done' after graduation"

# 3. AGENTS.md no longer says 'unpersonalized'.
python3 -c "
with open('$DOTSRC/AGENTS.md') as f:
    content = f.read()
if 'unpersonalized' in content:
    raise SystemExit('AGENTS.md still contains unpersonalized marker')
if 'Test User' not in content:
    raise SystemExit('AGENTS.md does not mention the user name')
print('PASS: AGENTS.md is personalized')
"

# 4. onboard/ is archived, not present at original path.
[[ ! -d "$DOTSRC/onboard" ]] || fail "onboard/ directory still exists after graduation (should be archived)"
pass "onboard/ is gone from original path"

[[ -d "$DOTSRC/.onboard-archive" ]] || fail ".onboard-archive/ does not exist after graduation"
pass ".onboard-archive/ exists"

# 5. dots help still works (CLI not broken by graduation).
DOTFILES_DIR="$DOTSRC" bash "$DOTSRC/bin/dots" help >/dev/null 2>&1 || fail "dots help failed after graduation"
pass "dots help works after graduation"

echo
echo "=== All e2e assertions passed ==="
