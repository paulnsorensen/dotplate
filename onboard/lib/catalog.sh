#!/usr/bin/env bash
# onboard/lib/catalog.sh — catalog entry helper.
#
# Usage:
#   bash onboard/lib/catalog.sh entry <catalog-file> <list-key> <index>
#       Print the entry field for the item at <index> under <list-key>.
#       Exits 1 (loud) when the entry is null or empty — a null entry in a
#       catalog item means the file was committed incomplete; applying it
#       silently would write 'null' into a registry or config.
#
# Example:
#   bash onboard/lib/catalog.sh entry onboard/catalog/zsh.yaml zsh 0

set -euo pipefail

cmd="${1:-}"

case "$cmd" in
    entry)
        catalog_file="${2:-}"
        list_key="${3:-}"
        idx="${4:-}"
        if [[ -z "$catalog_file" || -z "$list_key" || -z "$idx" ]]; then
            echo "catalog.sh entry: usage: entry <catalog-file> <list-key> <index>" >&2
            exit 1
        fi
        if [[ ! -f "$catalog_file" ]]; then
            echo "catalog.sh entry: file not found: $catalog_file" >&2
            exit 1
        fi
        entry=$(yq ".${list_key}[${idx}].entry" "$catalog_file")
        if [[ -z "$entry" || "$entry" == "null" ]]; then
            name=$(yq ".${list_key}[${idx}].name // \"(unknown)\"" "$catalog_file")
            echo "catalog.sh entry: null or missing entry for item '$name' at ${list_key}[${idx}] in $catalog_file" >&2
            exit 1
        fi
        printf '%s\n' "$entry"
        ;;
    *)
        echo "Usage: catalog.sh entry <catalog-file> <list-key> <index>" >&2
        exit 1
        ;;
esac
