#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Deploying GitOps homelab stack..."
echo "------------------------------"

# Define directories for GitOps (container-local paths)
GITOPS_ROOT="/opt/gitops"
mkdir -p "$GITOPS_ROOT"

# Example: clone GitOps repo (user can replace with own repo)
GITOPS_REPO="https://github.com/ColdShadow80/homelab-gitops.git"

if [ ! -d "$GITOPS_ROOT/.git" ]; then
    git clone "$GITOPS_REPO" "$GITOPS_ROOT"
else
    echo "GitOps repo already exists. Pulling latest changes..."
    git -C "$GITOPS_ROOT" pull
fi

# Example: deploy stack using docker-compose
DOCKER_COMPOSE_FILE="$GITOPS_ROOT/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    echo "✅ GitOps homelab deployed using docker-compose."
else
    echo "WARNING: docker-compose.yml not found in $GITOPS_ROOT. Skipping deployment."
fi
