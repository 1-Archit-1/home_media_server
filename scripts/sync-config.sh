#!/usr/bin/env bash
# Deliberately replace selected runtime configuration files with backed-up templates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

usage() {
    cat <<'EOF'
Usage: ./sync-config.sh [--dry-run] [--yes] <target>

Targets: homepage, qbittorrent, deluge, decypharr, docker-gc, aliases, all

The selected runtime files are backed up beside their destination before they
are replaced. Use --dry-run to preview and --yes to skip confirmation.
EOF
}

dry_run=false
yes=false
target=""
while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --yes) yes=true ;;
        -h|--help) usage; exit 0 ;;
        homepage|qbittorrent|deluge|decypharr|docker-gc|aliases|all)
            [[ -z "$target" ]] || { usage >&2; exit 1; }
            target="$1"
            ;;
        *) usage >&2; exit 1 ;;
    esac
    shift
done

[[ -n "$target" ]] || { usage >&2; exit 1; }

declare -a sources destinations
add_file() {
    sources+=("$1")
    destinations+=("$2")
}

if [[ "$target" == "homepage" || "$target" == "all" ]]; then
    for file in bookmarks.yaml services.yaml settings.yaml widgets.yaml; do
        add_file "$HOMEPAGE_CONFIG/$file" "$APPDATA/homepage/$file"
    done
fi
if [[ "$target" == "qbittorrent" || "$target" == "all" ]]; then
    add_file "$QBITTORRENT_CONFIG" "$QBITTORRENT_CONF"
fi
if [[ "$target" == "deluge" || "$target" == "all" ]]; then
    add_file "$DELUGE_CONFIG1" "$DELUGE_CONF1"
    add_file "$DELUGE_CONFIG2" "$DELUGE_CONF2"
fi
if [[ "$target" == "decypharr" || "$target" == "all" ]]; then
    add_file "$DECYPHARR_CONFIG" "$APPDATA/decypharr/config.json"
fi
if [[ "$target" == "docker-gc" || "$target" == "all" ]]; then
    add_file "$DOCKERGC_EXCLUDE" "$APPDATA/docker-gc/docker-gc-exclude"
fi
if [[ "$target" == "aliases" || "$target" == "all" ]]; then
    add_file "./bash_aliases" "$BASH_CONFIG"
fi

for source_file in "${sources[@]}"; do
    [[ -f "$source_file" ]] || { echo "Missing template: $source_file" >&2; exit 1; }
done

echo "The following runtime files will be replaced:"
for destination in "${destinations[@]}"; do
    echo "  - $destination"
done

if "$dry_run"; then
    echo "Dry run complete; no files were changed."
    exit 0
fi

if ! "$yes"; then
    read -r -p "Back up and replace these files? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || { echo "No changes made."; exit 0; }
fi

timestamp="$(date +%Y%m%d%H%M%S)"
for index in "${!sources[@]}"; do
    source_file="${sources[$index]}"
    destination="${destinations[$index]}"
    mkdir -p "$(dirname "$destination")"

    if [[ -e "$destination" ]]; then
        backup="${destination}.bak.${timestamp}"
        cp -a "$destination" "$backup"
        echo "Backed up $destination to $backup"
    fi

    cp "$source_file" "$destination"
    echo "Synced $source_file to $destination"
done

echo "Configuration sync complete. Restart or recreate the affected service when required."
