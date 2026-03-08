#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

REPO_REF="${REPO_REF:-main}"
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/${REPO_REF}/scripts"
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"
echo "Using repository ref: $REPO_REF"

# ------------------------------
# Function to fetch scripts safely
# ------------------------------
fetch_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    local local_path="$SCRIPT_DIR/$script_name"

    echo "" >&2
    echo "------------------------------" >&2
    echo "Fetching script: $script_name" >&2
    echo "URL: $url" >&2
    echo "------------------------------" >&2

    # Download script
    curl -fsSL "$url" -o "$local_path"

    # Verify file exists
    if [ ! -f "$local_path" ]; then
        echo "ERROR: Failed to download $script_name" >&2
        exit 1
    fi

    # Fix line endings to Unix style
    if command -v dos2unix >/dev/null 2>&1; then
        dos2unix "$local_path" &>/dev/null || true
    fi

    # Make executable
    chmod +x "$local_path"

    echo "✅ Successfully downloaded and made executable: $script_name" >&2
    printf '%s\n' "$local_path"
}

# ------------------------------
# Function to run a script (bash or source)
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
# Step 2: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
run_script "$CTID_SCRIPT" source
echo "Next available CTID(s) to be used: $CTID"

# ------------------------------
# Step 3: LXC creation
# ------------------------------
LXC_SCRIPT=$(fetch_script "03-create-lxc.sh")
export ZFS_POOL
export CTID
run_script "$LXC_SCRIPT" bash
