#!/usr/bin/env bash
# onboard/lib/state.sh — tiny helper for reading onboarding state.
#
# Usage:
#   bash onboard/lib/state.sh next  <state-file>          # print first pending pass index, or 'done'
#   bash onboard/lib/state.sh get   <state-file> <path>   # read a yq path from the state file
#
# The GUIDE agent MAY use this helper or read state.yaml directly with yq.
# The helper exists so the resumability contract is executable and testable.

set -euo pipefail

cmd="${1:-}"
state_file="${2:-onboard/state.yaml}"

if [[ ! -f "$state_file" ]]; then
    echo "state.sh: file not found: $state_file" >&2
    exit 1
fi

case "$cmd" in
    next)
        # Validate: every pass must have status 'pending' or 'done'.
        # Unknown statuses (e.g. 'in-progress') are a data error — fail loud so
        # the agent does not silently skip or misread the resume point.
        bad=$(yq '.passes[] | select(.status != "pending" and .status != "done") | .index' "$state_file" 2>/dev/null || true)
        if [[ -n "$bad" ]]; then
            echo "state.sh: pass(es) $bad have unknown status (expected pending or done)" >&2
            exit 1
        fi
        # Print the index of the first pass with status 'pending', or 'done'.
        result=$(yq '.passes[] | select(.status == "pending") | .index' "$state_file" \
            | head -n1)
        if [[ -z "$result" ]]; then
            echo "done"
        else
            echo "$result"
        fi
        ;;
    get)
        yq_path="${3:-}"
        if [[ -z "$yq_path" ]]; then
            echo "state.sh get: missing yq path argument" >&2
            exit 1
        fi
        yq "$yq_path" "$state_file"
        ;;
    *)
        echo "Usage: state.sh next|get <state-file> [<yq-path>]" >&2
        exit 1
        ;;
esac
