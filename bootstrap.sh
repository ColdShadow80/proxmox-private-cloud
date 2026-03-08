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

    # Convert to Unix line endings to prevent 'No such file or directory'
    if command -v dos2unix &>/dev/null; then
        dos2unix "$local_path" &>/dev/null || true
    else
        sed -i 's/\r$//' "$local_path"
    fi

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
# Step 1: Embedded ZFS setup (reliable)
# ------------------------------
echo ""
echo "------------------------------"
echo "Running embedded ZFS setup..."
echo "------------------------------"

POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}

if [ "$NUM_POOLS" -eq 0 ]; then
    echo "ERROR: No ZFS pools detected! Please create a ZFS pool first."
    exit 1
elif [ "$NUM_POOLS" -eq 1 ]; then
    POOL="${POOLS[0]}"
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    echo "Multiple ZFS pools detected. Please select one to use:"
    for i in "${!POOLS[@]}"; do
        echo "[$i] ${POOLS[$i]}"
    done
    read -p "Enter the number of the pool to use: " POOL_INDEX
    POOL="${POOLS[$POOL_INDEX]}"
fi

DATASET=docker
if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    zfs create "$POOL/$DATASET"
    echo "Created ZFS dataset '$POOL/$DATASET'."
fi

export ZFS_POOL="$POOL"
echo "✅ ZFS setup completed using pool: $ZFS_POOL"

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
