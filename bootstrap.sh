#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"

echo "Starting Proxmox GitOps Homelab Deployment..."

curl -fsSL $REPO/01-detect-ctid.sh | bash
curl -fsSL $REPO/02-create-zfs.sh | bash
curl -fsSL $REPO/03-create-lxc.sh | bash
curl -fsSL $REPO/04-configure-network.sh | bash
curl -fsSL $REPO/05-install-docker.sh | bash
curl -fsSL $REPO/06-deploy-gitops.sh | bash
curl -fsSL $REPO/07-configure-cloudflare.sh | bash
curl -fsSL $REPO/08-deploy-dashboard.sh | bash
curl -fsSL $REPO/09-summary.sh | bash

echo "Deployment complete! Access your homelab at your configured IP or domain."
