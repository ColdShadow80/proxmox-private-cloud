#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Deploying Dashboard..."
echo "------------------------------"

# Define dashboard data path (container-local)
DASHBOARD_ROOT="/opt/dashboard"
mkdir -p "$DASHBOARD_ROOT"

# Example: deploy dashboard using docker-compose
DASHBOARD_REPO="https://github.com/ColdShadow80/homelab-dashboard.git"
if [ ! -d "$DASHBOARD_ROOT/.git" ]; then
    git clone "$DASHBOARD_REPO" "$DASHBOARD_ROOT"
else
    echo "Dashboard repo already exists. Pulling latest changes..."
    git -C "$DASHBOARD_ROOT" pull
fi

DOCKER_COMPOSE_FILE="$DASHBOARD_ROOT/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    echo "✅ Dashboard deployed on $ZFS_POOL/dashboard"
else
    echo "WARNING: docker-compose.yml not found in $DASHBOARD_ROOT. Skipping dashboard deployment."
fi
