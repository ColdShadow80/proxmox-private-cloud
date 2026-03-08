#!/usr/bin/env bash
set -e

# ------------------------------
# Validate required variables
# ------------------------------
: "${ZFS_POOL:?ZFS_POOL must be set}"
: "${CTID:?CTID must be set}"

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

echo "Using CTID: $CTID"

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

# Choose Debian major version (default: 12)
read -rp "Debian major version for LXC template [12]: " DEBIAN_MAJOR_INPUT
if [ -n "$DEBIAN_MAJOR_INPUT" ]; then
    if ! [[ "$DEBIAN_MAJOR_INPUT" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Debian version must be a number (example: 12)."
        exit 1
    fi
    DEBIAN_MAJOR="$DEBIAN_MAJOR_INPUT"
else
    DEBIAN_MAJOR=12
fi

# Pick latest matching Debian standard template from upstream list
TEMPLATE_PATTERN="^debian-${DEBIAN_MAJOR}-standard_.*_amd64\\.tar\\.zst$"
TEMPLATE_NAME=$(pveam available --section system 2>/dev/null | awk 'NR>1 {print $2}' | grep -E "$TEMPLATE_PATTERN" | sort -V | tail -n1)
if [ -z "$TEMPLATE_NAME" ]; then
    echo "ERROR: Could not find an available Debian ${DEBIAN_MAJOR} standard template in pveam!"
    exit 1
fi
echo "Using template: $TEMPLATE_NAME"

# Download template if not present
if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE_NAME"; then
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
