#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main"

echo "Starting Proxmox GitOps Homelab Deployment..."

curl -fsSL $REPO/scripts/01-detect-ctid.sh | bash
curl -fsSL $REPO/scripts/02-create-zfs.sh | bash
curl -fsSL $REPO/scripts/03-create-lxc.sh | bash
curl -fsSL $REPO/scripts/04-configure-network.sh | bash
curl -fsSL $REPO/scripts/05-install-docker.sh | bash
curl -fsSL $REPO/scripts/06-deploy-gitops.sh | bash
curl -fsSL $REPO/scripts/07-configure-cloudflare.sh | bash
curl -fsSL $REPO/scripts/08-deploy-dashboard.sh | bash
curl -fsSL $REPO/scripts/09-summary.sh | bash

echo "Deployment complete! Access your homelab at your configured IP or domain."
