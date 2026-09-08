#!/usr/bin/env bash
# Deploy the canonical Compose definitions without overwriting application data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

require_file() {
    [[ -f "$1" ]] || { echo "Missing required file: $1" >&2; exit 1; }
}

require_file "$SOURCE_COMPOSE"
command -v docker >/dev/null || { echo "Docker is not installed." >&2; exit 1; }

python3 "$SCRIPT_DIR/update-env.py"
require_file "$ENV_FILE"

mkdir -p "$COMPOSE"
cp "$SOURCE_COMPOSE" "$COMPOSE_FILE"
cp "$COMPOSE_FILES"/*.yml "$COMPOSE/"

echo "Validating Compose configuration..."
sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config -q

echo "Deploying stack..."
sudo docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans

echo "Deployment complete: $COMPOSE_FILE"
