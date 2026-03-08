#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

# ------------------------------
# Temporary script directory
# ------------------------------
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"

# ------------------------------
# Base URL for scripts
# ------------------------------
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"

# ------------------------------
# Fetch script safely
# ------------------------------
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

    if [ ! -f "$local_path" ]; then
        echo "ERROR: Failed to download $script_name"
        exit 1
    fi

    chmod +x "$local_path"
    echo "✅ Successfully downloaded and made executable: $script_name"
    echo "$local_path"
}

# ------------------------------
# Run script safely
# ------------------------------
run_script() {
    local script_path="$1"
    local mode="${2:-bash}"  # default: run in bash

    echo ""
    echo "------------------------------"
    echo "Running script: $(basename "$script_path")"
    echo "------------------------------"

    if [ "$mode" = "source" ]; then
        source "$script_path"
    else
        bash "$script_path"
    fi
}

# ------------------------------
# Step 1: ZFS setup
# ------------------------------
ZFS_SCRIPT=$(fetch_script "02-create-zfs.sh")
run_script "$ZFS_SCRIPT" source
export ZFS_POOL  # make sure it's exported for other scripts

# ------------------------------
# Step 2: Determine starting CTID
# ------------------------------
read -p 'Do you want to specify a starting container ID? [y/N]: ' START_CID_ANSWER
if [[ "$START_CID_ANSWER" =~ ^[Yy]$ ]]; then
    read -p 'Enter starting CTID number: ' START_CID
else
    START_CID=100
fi
echo "Starting CTID set to: $START_CID"
export START_CID

# ------------------------------
# Step 3: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
run_script "$CTID_SCRIPT" source
export CTID
echo "Next available CTID(s) to be used: $CTID"

# ------------------------------
# Step 4: Create LXC container
# ------------------------------
LXC_SCRIPT=$(fetch_script "03-create-lxc.sh")
run_script "$LXC_SCRIPT"
