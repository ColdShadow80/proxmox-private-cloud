#!/usr/bin/env bash
set -e

BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"

run_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    echo ""
    echo "------------------------------"
    echo "Fetching and running: $script_name"
    echo "URL: $url"
    echo "------------------------------"
    curl -fsSL "$url" | bash
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to fetch or run $script_name"
    fi
}

echo "Starting Proxmox GitOps Homelab Deployment..."

run_script "01-detect-ctid.sh"
run_script "02-create-zfs.sh"
run_script "03-create-lxc.sh"
run_script "04-configure-network.sh"
run_script "05-install-docker.sh"
run_script "06-deploy-gitops.sh"
run_script "07-configure-cloudflare.sh"
run_script "07a-cloudflared-setup.sh"
run_script "08-deploy-dashboard.sh"
run_script "09-summary.sh"

echo ""
echo "Deployment complete! Access your homelab at your configured IP or domain."
