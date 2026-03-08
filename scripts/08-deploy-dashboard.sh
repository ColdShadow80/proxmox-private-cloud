#!/usr/bin/env bash
set -e

# Ensure ZFS_POOL is defined
if [ -z "$ZFS_POOL" ]; then
    echo "ERROR: ZFS_POOL not defined. Run 02-create-zfs.sh first."
    exit 1
fi

echo "------------------------------"
echo "Deploying Dashboard..."
echo "------------------------------"

# Define dashboard data path on ZFS pool
DASHBOARD_ROOT="$ZFS_POOL/dashboard"
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
