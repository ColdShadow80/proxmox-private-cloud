#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

# Base URL for scripts
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"

# Directory to download scripts temporarily
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"

# Function to fetch a script
fetch_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    local local_path="$SCRIPT_DIR/$script_name"
    echo ""
    echo "------------------------------"
    echo "Fetching script: $script_name"
    echo "URL: $url"
    echo "------------------------------"
    curl -fsSL "$url" -o "$local_path"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to fetch $script_name"
        exit 1
    fi
    echo "$local_path"
}

# Function to run a script in a subshell
run_script() {
    local script_path="$1"
    echo ""
    echo "------------------------------"
    echo "Running script: $(basename $script_path)"
    echo "------------------------------"
    bash "$script_path"
}

# ------------------------------
# Step 1: Setup ZFS
# ------------------------------
ZFS_SCRIPT=$(fetch_script "02-create-zfs.sh")
source "$ZFS_SCRIPT"   # Source so $POOL is exported in parent shell
export ZFS_POOL="$POOL"

# ------------------------------
# Step 2: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
source "$CTID_SCRIPT"  # Source so $CTID is exported in parent shell
export CTID
echo "Next container ID to use: $CTID"

# ------------------------------
# Step 3: Create LXC container
# ------------------------------
LXC_SCRIPT=$(fetch_script "03-create-lxc.sh")
run_script "$LXC_SCRIPT"

# ------------------------------
# Step 4: Configure network
# ------------------------------
NET_SCRIPT=$(fetch_script "04-configure-network.sh")
run_script "$NET_SCRIPT"

# ------------------------------
# Step 5: Install Docker
# ------------------------------
DOCKER_SCRIPT=$(fetch_script "05-install-docker.sh")
run_script "$DOCKER_SCRIPT"

# ------------------------------
# Step 6: Deploy GitOps homelab
# ------------------------------
GITOPS_SCRIPT=$(fetch_script "06-deploy-gitops.sh")
run_script "$GITOPS_SCRIPT"

# ------------------------------
# Step 7: Configure Cloudflare tunnel
# ------------------------------
CF_SCRIPT=$(fetch_script "07-configure-cloudflare.sh")
run_script "$CF_SCRIPT"

# ------------------------------
# Step 7a: Optional Cloudflare setup
# ------------------------------
CF_TUNNEL_SCRIPT=$(fetch_script "07a-cloudflared-setup.sh")
run_script "$CF_TUNNEL_SCRIPT"

# ------------------------------
# Step 8: Deploy Dashboard
# ------------------------------
DASH_SCRIPT=$(fetch_script "08-deploy-dashboard.sh")
run_script "$DASH_SCRIPT"

# ------------------------------
# Step 9: Summary
# ------------------------------
SUMMARY_SCRIPT=$(fetch_script "09-summary.sh")
run_script "$SUMMARY_SCRIPT"

echo ""
echo "=============================="
echo "Deployment complete! Access your homelab at your configured IP or domain."
echo "=============================="
