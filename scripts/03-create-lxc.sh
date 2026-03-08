#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

CTID=${START_CID:-${CTID:-100}}
echo "Using starting CTID: $CTID"

# Detect local storage for templates (ZFSPool or dir)
TEMPLATE_STORAGE=$(pvesm status | awk 'NR>1 && $2 ~ /dir|zfspool|nfs/ {print $1; exit}')
if [ -z "$TEMPLATE_STORAGE" ]; then
    echo "ERROR: No suitable storage found for LXC templates!"
    exit 1
fi
echo "Using storage for templates: $TEMPLATE_STORAGE"

# Update Proxmox template list
echo "Updating Proxmox LXC template list..."
pveam update

# Get exact template name from Proxmox repo
TEMPLATE_NAME=$(pveam available | awk '/debian-12-standard/ {print $1; exit}')
if [ -z "$TEMPLATE_NAME" ]; then
    echo "ERROR: Debian 12 LXC template not found in Proxmox repository!"
    exit 1
fi
echo "Using template: $TEMPLATE_NAME"

# Download template if not already present
if ! ls "$TEMPLATE_STORAGE"/vztmpl/*"$TEMPLATE_NAME"* &>/dev/null; then
    echo "Downloading template $TEMPLATE_NAME to storage $TEMPLATE_STORAGE..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
else
    echo "Template $TEMPLATE_NAME already exists on $TEMPLATE_STORAGE."
fi

# Create container
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
