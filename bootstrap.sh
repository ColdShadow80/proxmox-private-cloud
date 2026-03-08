#!/usr/bin/env bash
set -e
set -x  # Debug: show commands as they execute

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

# ------------------------------
# Base configuration
# ------------------------------
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"
SCRIPT_DIR="/tmp/proxmox-scripts"

# Ensure temp folder exists
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"

# ------------------------------
# Function to fetch a script
# ------------------------------
fetch_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    local local_path="$SCRIPT_DIR/$script_name"

    # Log to stderr
    >&2 echo ""
    >&2 echo "------------------------------"
    >&2 echo "Fetching script: $script_name"
    >&2 echo "URL: $url"
    >&2 echo "------------------------------"

    curl -fsSL "$url" -o "$local_path"
    if [ ! -f "$local_path" ]; then
        >&2 echo "ERROR: Failed to download $script_name from $url"
        exit 1
    fi

    # Show file info to stderr
    >&2 ls -l "$local_path"
    >&2 echo "✅ Successfully downloaded $script_name"

    # Output path to stdout only
    echo "$local_path"
}

# ------------------------------
# Function to run a script
# ------------------------------
run_script() {
    local script_path="$1"
    local mode="${2:-bash}" # default run with bash
    >&2 echo ""
    >&2 echo "------------------------------"
    >&2 echo "Running script: $(basename $script_path)"
    >&2 echo "------------------------------"
    if [ "$mode" = "source" ]; then
        source "$script_path"
    else
        bash "$script_path"
    fi
}

# ------------------------------
# Step 1: Setup ZFS (export $POOL)
# ------------------------------
ZFS_SCRIPT=$(fetch_script "02-create-zfs.sh")
run_script "$ZFS_SCRIPT" source
export ZFS_POOL="$POOL"

# ------------------------------
# Step 2: Detect next free CTID (export $CTID)
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
run_script "$CTID_SCRIPT" source
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
