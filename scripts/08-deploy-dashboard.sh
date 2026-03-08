#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Deploying Dashboard..."
echo "------------------------------"

# Define dashboard data path (container-local)
DASHBOARD_ROOT="/opt/dashboard"
mkdir -p "$DASHBOARD_ROOT"

# Check if custom dashboard repo is specified, otherwise create simple default
DASHBOARD_REPO="${DASHBOARD_REPO:-}"

if [ -n "$DASHBOARD_REPO" ]; then
    if [ ! -d "$DASHBOARD_ROOT/.git" ]; then
        echo "Cloning dashboard repository: $DASHBOARD_REPO"
        git clone "$DASHBOARD_REPO" "$DASHBOARD_ROOT"
    else
        echo "Dashboard repo already exists. Pulling latest changes..."
        git -C "$DASHBOARD_ROOT" pull
    fi
    
    DOCKER_COMPOSE_FILE="$DASHBOARD_ROOT/docker-compose.yml"
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        echo "✅ Dashboard deployed"
    else
        echo "WARNING: docker-compose.yml not found in $DASHBOARD_ROOT. Skipping dashboard deployment."
    fi
else
    echo "No DASHBOARD_REPO configured. Skipping dashboard deployment."
    echo "To deploy a custom dashboard, set DASHBOARD_REPO environment variable."
fi
