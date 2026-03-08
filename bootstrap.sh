#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"

# ------------------------------
# Function to fetch scripts safely
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

    # Convert line endings to Unix
    if command -v dos2unix &>/dev/null; then
        dos2unix "$local_path" &>/dev/null || true
    else
        sed -i 's/\r$//' "$local_path"
    fi

    # Make executable
    chmod +x "$local_path"

    echo "✅ Successfully downloaded $script_name"
    echo "$local_path"
}

# ------------------------------
# Run script (source or bash)
# ------------------------------
run_script() {
    local script_path="$1"
    local mode="${2:-bash}"

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

# ------------------------------
# Step 3: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
export START_CID
run_script "$CTID_SCRIPT" source
echo "Next available CTID(s) to be used: $CTID"

# ------------------------------
# Step 4: LXC creation
# ------------------------------
LXC_SCRIPT=$(fetch_script "03-create-lxc.sh")
run_script "$LXC_SCRIPT"
