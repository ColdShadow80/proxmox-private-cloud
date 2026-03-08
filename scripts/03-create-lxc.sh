#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

# Validate required variables
if [ -z "$CTID" ]; then
    echo "ERROR: CTID not defined. Run 01-detect-ctid.sh first."
    exit 1
fi
if [ -z "$ZFS_POOL" ]; then
    echo "ERROR: ZFS_POOL not defined. Run 02-create-zfs.sh first."
    exit 1
fi

LXC_HOSTNAME="homelab-${CTID}"
echo "Using starting CTID: $CTID"
echo "Hostname will be: $LXC_HOSTNAME"

# Find storage for templates
TEMPLATE_STORAGE=$(pvesm status | awk 'NR>1 && $2 ~ /dir|nfs|zfspool/ {print $1; exit}')
if [ -z "$TEMPLATE_STORAGE" ]; then
    echo "ERROR: No suitable storage found for LXC templates!"
    exit 1
fi
echo "Using storage for templates: $TEMPLATE_STORAGE"

# Update template list
echo "Updating Proxmox LXC template list..."
pveam update

# Template name
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64"

# Check if template exists in list
if ! pveam list | grep -q "$TEMPLATE_NAME"; then
    echo "ERROR: Template $TEMPLATE_NAME not found in Proxmox template list!"
    exit 1
fi

# Download template if missing
if ! ls "$TEMPLATE_STORAGE"/vztmpl/*"$TEMPLATE_NAME"* &>/dev/null; then
    echo "Downloading template $TEMPLATE_NAME to storage $TEMPLATE_STORAGE..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
else
    echo "Template $TEMPLATE_NAME already exists on $TEMPLATE_STORAGE."
fi

# Create LXC container
echo "Creating LXC container ID $CTID..."
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
