#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

# Ensure ZFS_POOL is defined
if [ -z "$ZFS_POOL" ]; then
    echo "ERROR: ZFS_POOL not defined. Run 02-create-zfs.sh first."
    exit 1
fi

# Determine starting CTID
CTID=${START_CID:-${CTID:-100}}
echo "Using starting CTID: $CTID"

# Select Proxmox storage for LXC template
# Check available storage
STORAGES=($(pvesm status | awk 'NR>1 {print $1}'))
if [ ${#STORAGES[@]} -eq 0 ]; then
    echo "ERROR: No Proxmox storage detected. Cannot proceed."
    exit 1
elif [ ${#STORAGES[@]} -eq 1 ]; then
    TEMPLATE_STORAGE="${STORAGES[0]}"
    echo "Only one storage detected. Using storage: $TEMPLATE_STORAGE"
else
    echo "Multiple storages detected:"
    for i in "${!STORAGES[@]}"; do
        echo "$((i+1))) ${STORAGES[$i]}"
    done
    read -p "Select storage for LXC templates (number): " STORAGE_CHOICE
    TEMPLATE_STORAGE="${STORAGES[$((STORAGE_CHOICE-1))]}"
    echo "Selected storage: $TEMPLATE_STORAGE"
fi

# Update Proxmox template list
echo "Updating Proxmox LXC template list..."
pveam update

# Check if template already exists in storage
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64"
if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE_NAME"; then
    echo "Template $TEMPLATE_NAME not found in storage $TEMPLATE_STORAGE. Downloading..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
else
    echo "Template $TEMPLATE_NAME already exists in $TEMPLATE_STORAGE."
fi

# Preview next free CTIDs
USED_CTIDS=($(pct list 2>/dev/null | awk 'NR>1 {print $1}'))
NEXT_CTID=$CTID
FREE_CTIDS=()
NUM_TO_DEPLOY=1  # Adjust if you deploy multiple containers

for ((i=0; i<NUM_TO_DEPLOY; i++)); do
    while [[ " ${USED_CTIDS[*]} " =~ " ${NEXT_CTID} " ]]; do
        NEXT_CTID=$((NEXT_CTID+1))
    done
    FREE_CTIDS+=("$NEXT_CTID")
    NEXT_CTID=$((NEXT_CTID+1))
done

echo "Next available container ID(s) to be used: ${FREE_CTIDS[*]}"
CTID="${FREE_CTIDS[0]}"

# Define container config
LXC_HOSTNAME="homelab-${CTID}"
LXC_ROOTFS="$ZFS_POOL/docker/vm-${CTID}-disk-0"

echo "Creating LXC container ID $CTID with hostname $LXC_HOSTNAME on $TEMPLATE_STORAGE..."

pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE_NAME" \
    --hostname "$LXC_HOSTNAME" \
    --rootfs "$ZFS_POOL/docker" \
    --cores 2 \
    --memory 2048 \
    --swap 512 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --password "changeme" \
    --features nesting=1

echo "Starting container $CTID..."
pct start "$CTID"

echo "✅ Container $CTID created and started successfully."
