#!/usr/bin/env bash
set -e

echo ""
echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

# Use environment variables set by bootstrap.sh
CTID=${CTID:-100}
ZFS_POOL=${ZFS_POOL:-VM-Storage-1TB}

# Detect storage for templates
TEMPLATE_STORAGE=$(pvesm status | awk 'NR>1 && $2 ~ /dir|nfs|zfspool/ {print $1; exit}')
if [ -z "$TEMPLATE_STORAGE" ]; then
    echo "ERROR: No suitable storage found for LXC templates!"
    exit 1
fi
echo "Using storage for templates: $TEMPLATE_STORAGE"

# Update template list
echo "Updating Proxmox LXC template list..."
pveam update

# Find latest Debian 12 template dynamically
TEMPLATE_NAME=$(pveam available | grep -m1 "debian-12-standard" | awk '{print $1}')
if [ -z "$TEMPLATE_NAME" ]; then
    echo "ERROR: Debian 12 template not found in Proxmox repository!"
    exit 1
fi
echo "Using template: $TEMPLATE_NAME"

# Download template if not present
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

pct start "$CTID"
echo "✅ Container $CTID created and started successfully."
