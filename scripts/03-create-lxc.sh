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

# Find storages that support container templates (vztmpl)
TEMPLATE_STORAGES=()
TEMPLATE_STORAGES_FREE=()

while IFS= read -r storage_id; do
    [ -z "$storage_id" ] && continue
    if pveam list "$storage_id" >/dev/null 2>&1; then
        free_kb=$(pvesm status | awk -v sid="$storage_id" '$1 == sid {print $6; exit}')
        free_kb="${free_kb//[^0-9]/}"
        if [ -z "$free_kb" ]; then
            free_kb=0
        fi
        TEMPLATE_STORAGES+=("$storage_id")
        TEMPLATE_STORAGES_FREE+=("$free_kb")
    fi
done < <(pvesm status | awk 'NR>1 {print $1}')

if [ ${#TEMPLATE_STORAGES[@]} -eq 0 ]; then
    echo "ERROR: No Proxmox storage supporting templates (vztmpl) was found."
    echo "Please enable 'Container template' content on at least one storage (for example 'local')."
    exit 1
fi

if [ ${#TEMPLATE_STORAGES[@]} -eq 1 ]; then
    TEMPLATE_STORAGE="${TEMPLATE_STORAGES[0]}"
    echo "Only one template-capable storage found. Using: $TEMPLATE_STORAGE"
else
    echo "Multiple template-capable storages detected:"
    best_index=0
    best_free="${TEMPLATE_STORAGES_FREE[0]}"

    for i in "${!TEMPLATE_STORAGES[@]}"; do
        storage_name="${TEMPLATE_STORAGES[$i]}"
        free_value="${TEMPLATE_STORAGES_FREE[$i]}"
        echo "[$((i + 1))] $storage_name (free: ${free_value} KB)"
        if [ "$free_value" -gt "$best_free" ]; then
            best_free="$free_value"
            best_index="$i"
        fi
    done

    default_storage="${TEMPLATE_STORAGES[$best_index]}"
    read -r -t 30 -p "Select template storage [1-${#TEMPLATE_STORAGES[@]}] within 30s (default: $default_storage): " storage_choice || true

    if [ -z "$storage_choice" ]; then
        TEMPLATE_STORAGE="$default_storage"
        echo "No selection made in 30 seconds. Using storage with most free space: $TEMPLATE_STORAGE"
    elif [[ "$storage_choice" =~ ^[0-9]+$ ]] && [ "$storage_choice" -ge 1 ] && [ "$storage_choice" -le ${#TEMPLATE_STORAGES[@]} ]; then
        TEMPLATE_STORAGE="${TEMPLATE_STORAGES[$((storage_choice - 1))]}"
    else
        echo "Invalid storage selection: '$storage_choice'"
        exit 1
    fi
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
