#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

# Base URL for scripts
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"

# Function to fetch and run scripts with logging
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
        exit 1
    fi
}

# ------------------------------
# Step 1: Setup ZFS
# ------------------------------
run_script "02-create-zfs.sh"

# Export the selected ZFS pool so all following scripts use it
export ZFS_POOL="$POOL"

# ------------------------------
# Step 2: Detect next free CTID
# ------------------------------
run_script "01-detect-ctid.sh"
export CTID="$CTID"

# ------------------------------
# Step 3: Create LXC container
# ------------------------------
run_script "03-create-lxc.sh"

# ------------------------------
# Step 4: Configure network
# ------------------------------
run_script "04-configure-network.sh"

# ------------------------------
# Step 5: Install Docker
# ------------------------------
run_script "05-install-docker.sh"

# ------------------------------
# Step 6: Deploy GitOps homelab
# ------------------------------
run_script "06-deploy-gitops.sh"

# ------------------------------
# Step 7: Configure Cloudflare tunnel
# ------------------------------
run_script "07-configure-cloudflare.sh"

# ------------------------------
# Step 7a: Optional Cloudflare setup (user domain)
# ------------------------------
run_script "07a-cloudflared-setup.sh"

# ------------------------------
# Step 8: Deploy Dashboard
# ------------------------------
run_script "08-deploy-dashboard.sh"

# ------------------------------
# Step 9: Summary
# ------------------------------
run_script "09-summary.sh"

echo ""
echo "=============================="
echo "Deployment complete! Access your homelab at your configured IP or domain."
echo "=============================="
