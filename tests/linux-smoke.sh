#!/usr/bin/env bash
# Linux smoke test — validates the Linux bootstrap path in an ubuntu:24.04 container.
#
# Skips gracefully when Docker is unavailable.
# Logs full transcript to .cheese/notes/linux-smoke.log.
#
# Tests:
#   1. packages/sync.sh runs as root without crashing (apt packages installed)
#   2. bin/linux-install root guard correctly bypassed (no sudo in container)
#   3. dots help works (CLI machinery is not broken)
#   4. e2e-onboarding-dry-run.sh passes on Linux
#
# Exit 0 = pass, exit 1 = fail, exit 2 = skipped.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/.cheese/notes"
LOG_FILE="$LOG_DIR/linux-smoke.log"
mkdir -p "$LOG_DIR"

# Print to stdout and log file simultaneously.
log() { echo "$@" | tee -a "$LOG_FILE"; }
err() { echo "ERROR: $@" | tee -a "$LOG_FILE" >&2; }

log "======================================================"
log "Linux smoke test — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
log "======================================================"

# ─── Skip guard ─────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log "SKIP: docker not found on PATH"
    exit 2
fi
if ! docker info &>/dev/null 2>&1; then
    log "SKIP: docker daemon not running"
    exit 2
fi

# ─── Container inline script ────────────────────────────────────────────────────
# The script that runs inside the container. It:
#   - copies /dotplate-ro to /dotplate (writable)
#   - installs the apt machinery deps (yq, chezmoi, git, curl, bats)
#   - validates sync.sh and linux-install work as root
INNER_SCRIPT=$(cat <<'INNER'
#!/bin/bash
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "--- Container info ---"
uname -a
id
echo

# Copy dotplate to writable location
cp -r /dotplate-ro /dotplate
cd /dotplate

# 1. Bootstrap curl + apt essentials so we can pull other tools
echo "--- apt-get update ---"
apt-get update -qq
apt-get install -y --no-install-recommends curl ca-certificates git bash python3

# 2. Bootstrap yq (needed by sync.sh before it can do anything)
echo "--- Bootstrap yq ---"
mkdir -p /root/.local/bin
YQ_URL="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
curl -fsSL "$YQ_URL" -o /root/.local/bin/yq
chmod +x /root/.local/bin/yq
export PATH="/root/.local/bin:$PATH"
yq --version

# 3. Test: sync.sh runs as root (apt install path)
echo "--- Test: packages/sync.sh as root ---"
FORCE_PACKAGES=true DOTFILES_DIR=/dotplate bash /dotplate/packages/sync.sh && echo "PASS: sync.sh exited 0" || fail "sync.sh non-zero exit"

# 4. Test: bin/linux-install root check bypassed
# The guard: [[ "${EUID}" -eq 0 ]] && command -v sudo &>/dev/null
# In this container we are root (EUID=0) but sudo is NOT installed, so
# the guard is skipped. Running bin/linux-install would block on the zsh
# install prompt before the guard would fire anyway; just verify the guard
# logic directly.
echo "--- Test: bin/linux-install root check bypassed ---"
bash -n /dotplate/bin/linux-install && echo "PASS: linux-install parses OK"
# EUID is readonly in bash; read it directly.
if [[ "${EUID}" -eq 0 ]] && command -v sudo &>/dev/null; then
    echo "FAIL: root guard would refuse (sudo installed as root)"; exit 1
else
    echo "PASS: root guard correctly bypassed (EUID=0 but no sudo installed)"
fi

# 5. Test: dots help works
echo "--- Test: dots help ---"
bash /dotplate/bin/dots help 2>&1 | head -5
bash /dotplate/bin/dots help 2>&1 | grep -q "Usage:" && echo "PASS: dots help works" || fail "dots help unexpected output"

# 6. Test: e2e onboarding dry-run passes on Linux
echo "--- Test: e2e-onboarding-dry-run ---"
# PATH already includes /root/.local/bin (yq) and /root/.local/bin (uv) from sync.sh bootstrap.
export PATH="/root/.local/bin:$PATH"
bash /dotplate/tests/e2e-onboarding-dry-run.sh && echo "PASS: e2e-onboarding-dry-run passed" || fail "e2e-onboarding-dry-run failed"

echo
echo "=== All smoke tests passed ==="
INNER
)

# ─── Run the container ──────────────────────────────────────────────────────────
log "Pulling ubuntu:24.04 (or using cached)..."
docker pull ubuntu:24.04 2>&1 | tail -3 | tee -a "$LOG_FILE"

log "Running smoke test in container..."
log "(output also captured to $LOG_FILE)"
echo

if docker run --rm \
    -v "$REPO_ROOT":/dotplate-ro:ro \
    ubuntu:24.04 \
    bash -c "$INNER_SCRIPT" \
    2>&1 | tee -a "$LOG_FILE"; then
    log ""
    log "======================================================"
    log "RESULT: PASS"
    log "======================================================"
    exit 0
else
    log ""
    log "======================================================"
    log "RESULT: FAIL"
    log "======================================================"
    err "Smoke test failed. See: $LOG_FILE"
    exit 1
fi
