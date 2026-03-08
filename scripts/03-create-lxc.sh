#!/usr/bin/env bash
set -e

# Ensure CTID is defined
if [ -z "$CTID" ]; then
    echo "ERROR: CTID not defined. Run 01-detect-ctid.sh first."
    exit 1
fi

# Ensure ZFS_POOL is defined
if [ -z "$ZFS_POOL" ]; then
    echo "ERROR: ZFS_POOL not defined. Run 02-create-zfs.sh first."
    exit 1
fi

# LXC template
TEMPLATE="debian-12-standard_12.12-1_amd64"

# Check if template exists
TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE}.tar.zst"
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Downloading Debian 12 template..."
    pveam update
    pveam download local "$TEMPLATE"
fi

# Create container
echo "Creating LXC container $CTID on ZFS pool $ZFS_POOL..."
pct create "$CTID" local:vztmpl/"$TEMPLATE".tar.zst \
  --hostname docker-host \
  --cores 4 \
  --memory 8192 \
  --rootfs "$ZFS_POOL:50" \
  --features nesting=1,keyctl=1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start "$CTID"
echo "✅ LXC container $CTID created and started on ZFS pool: $ZFS_POOL"
