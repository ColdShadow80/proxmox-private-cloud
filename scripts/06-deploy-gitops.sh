#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Deploying GitOps homelab stack..."
echo "------------------------------"

# Define directories for GitOps (container-local paths)
GITOPS_ROOT="/opt/gitops"
mkdir -p "$GITOPS_ROOT"

# Use the main proxmox-private-cloud repo (which has stacks folder)
# Or override with GITOPS_REPO environment variable
GITOPS_REPO="${GITOPS_REPO:-https://github.com/ColdShadow80/proxmox-private-cloud.git}"

if [ ! -d "$GITOPS_ROOT/.git" ]; then
    echo "Cloning repository: $GITOPS_REPO"
    git clone "$GITOPS_REPO" "$GITOPS_ROOT"
else
    echo "GitOps repo already exists. Pulling latest changes..."
    git -C "$GITOPS_ROOT" pull
fi

# Look for docker-compose files in stacks/ or root directory
DOCKER_COMPOSE_FILE=""
if [ -f "$GITOPS_ROOT/stacks/homelab-stack.yml" ]; then
    DOCKER_COMPOSE_FILE="$GITOPS_ROOT/stacks/homelab-stack.yml"
elif [ -f "$GITOPS_ROOT/stacks/homelab-stack.yml.example" ]; then
    echo "Using homelab-stack.yml.example as template..."
    cp "$GITOPS_ROOT/stacks/homelab-stack.yml.example" "$GITOPS_ROOT/stacks/homelab-stack.yml"
    DOCKER_COMPOSE_FILE="$GITOPS_ROOT/stacks/homelab-stack.yml"
    echo "NOTE: Edit $GITOPS_ROOT/stacks/homelab-stack.yml to customize your services."
elif [ -f "$GITOPS_ROOT/docker-compose.yml" ]; then
    DOCKER_COMPOSE_FILE="$GITOPS_ROOT/docker-compose.yml"
fi

if [ -n "$DOCKER_COMPOSE_FILE" ]; then
    echo "Deploying stack from: $DOCKER_COMPOSE_FILE"
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    echo "✅ GitOps homelab deployed using docker-compose."
else
    echo "WARNING: No docker-compose file found in $GITOPS_ROOT. Skipping deployment."
    echo "To deploy your own stack, set GITOPS_REPO environment variable or add homelab-stack.yml"
fi
