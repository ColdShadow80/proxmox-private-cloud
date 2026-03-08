#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

# Use starting CTID from environment or fallback
CTID=${START_CID:-${CTID:-100}}
echo "Using starting CTID: $CTID"

# Detect storage suitable for LXC templates
TEMPLATE_STORAGE=$(pvesm status | awk 'NR>1 && $2 ~ /dir|nfs|zfspool/ {print $1; exit}')
if [ -z "$TEMPLATE_STORAGE" ]; then
    echo "ERROR: No suitable storage found for LXC templates!"
    exit 1
fi
echo "Using storage for templates: $TEMPLATE_STORAGE"

# Update Proxmox template list
echo "Updating Proxmox LXC template list..."
pveam update

# Template name to use
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64"

# Check if template exists
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

# Start container
pct start "$CTID"
echo "✅ Container $CTID created and started successfully."
