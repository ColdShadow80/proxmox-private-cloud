#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"

# ------------------------------
# 02-create-zfs.sh embedded
# ------------------------------
echo "------------------------------"
echo "Running embedded ZFS setup..."
echo "------------------------------"
# ZFS setup
POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}
if [ $NUM_POOLS -eq 0 ]; then
    echo "ERROR: No ZFS pools found!" >&2
    exit 1
elif [ $NUM_POOLS -eq 1 ]; then
    POOL=${POOLS[0]}
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    echo "Available ZFS pools: ${POOLS[*]}"
    read -p "Enter ZFS pool to use: " POOL
fi

DATASET=docker
if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    zfs create "$POOL/$DATASET"
    echo "Created ZFS dataset '$POOL/$DATASET'."
fi
export POOL
export ZFS_POOL="$POOL"
echo "✅ ZFS setup completed using pool: $POOL"

# ------------------------------
# Step 2: Starting CTID
# ------------------------------
read -p 'Do you want to specify a starting container ID? [y/N]: ' START_CID_ANSWER
if [[ "$START_CID_ANSWER" =~ ^[Yy]$ ]]; then
    read -p 'Enter starting CTID number: ' START_CID
else
    START_CID=100
fi
echo "Starting CTID set to: $START_CID"

# ------------------------------
# 01-detect-ctid.sh embedded
# ------------------------------
echo "------------------------------"
echo "Detecting next free CTID(s)..."
echo "------------------------------"

USED_CTIDS=($(pct list 2>/dev/null | awk 'NR>1 {print $1}'))
MAX_CTID=999
FREE_CTIDS=()
candidate=$START_CID
while [ ${#FREE_CTIDS[@]} -lt 1 ] && [ $candidate -le $MAX_CTID ]; do
    if [[ ! " ${USED_CTIDS[*]} " =~ " $candidate " ]]; then
        FREE_CTIDS+=($candidate)
    fi
    ((candidate++))
done

CTID=${FREE_CTIDS[0]:-$START_CID}
export CTID
echo "Next available CTID: $CTID"

# ------------------------------
# 03-create-lxc.sh embedded
# ------------------------------
echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

TEMPLATE_STORAGE=$(pvesm status | awk 'NR>1 && $2 ~ /dir|nfs|zfspool/ {print $1; exit}')
if [ -z "$TEMPLATE_STORAGE" ]; then
    echo "ERROR: No suitable storage found for LXC templates!" >&2
    exit 1
fi
echo "Using storage for templates: $TEMPLATE_STORAGE"

# Update template list
echo "Updating Proxmox LXC template list..."
pveam update

# Ensure template exists
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64"
if ! pveam list | grep -q "$TEMPLATE_NAME"; then
    echo "Downloading template $TEMPLATE_NAME to storage $TEMPLATE_STORAGE..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
else
    echo "Template $TEMPLATE_NAME already exists on $TEMPLATE_STORAGE."
fi

# Create LXC
LXC_HOSTNAME="homelab-${CTID}"
echo "Creating LXC container ID $CTID with hostname $LXC_HOSTNAME..."
pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE_NAME" \
    --hostname "$LXC_HOSTNAME" \
    --rootfs "$ZFS_POOL/docker" \
    --cores 2 \
    --memory 2048 \
    --swap 512 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --password "changeme" \
    --features nesting=1

pct start "$CTID"
echo "✅ Container $CTID created and started successfully."
