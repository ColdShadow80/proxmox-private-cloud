#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Running embedded ZFS setup..."
echo "------------------------------"

# ------------------------------
# Function to display ZFS pool info
# ------------------------------
display_pool_info() {
    local pool="$1"
    zpool list -o name,size,alloc,free,cap,health "$pool" | awk 'NR==1{print ""; print $0} NR>1{print $0}'
}

# ------------------------------
# Detect available ZFS pools
# ------------------------------
POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}

if [ $NUM_POOLS -eq 0 ]; then
    echo "ERROR: No ZFS pools detected on this system!"
    exit 1
elif [ $NUM_POOLS -eq 1 ]; then
    POOL="${POOLS[0]}"
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    echo "Multiple ZFS pools detected. Please select one to use:"
    for i in "${!POOLS[@]}"; do
        echo "[$i] ${POOLS[$i]}"
        display_pool_info "${POOLS[$i]}"
        echo "------------------------------"
    done
    read -p "Enter the number corresponding to the pool you want to use: " POOL_INDEX
    if ! [[ "$POOL_INDEX" =~ ^[0-9]+$ ]] || [ "$POOL_INDEX" -lt 0 ] || [ "$POOL_INDEX" -ge "$NUM_POOLS" ]; then
        echo "Invalid selection. Exiting."
        exit 1
    fi
    POOL="${POOLS[$POOL_INDEX]}"
    echo "Selected ZFS pool: $POOL"
fi

# ------------------------------
# Create docker dataset if missing
# ------------------------------
DATASET="docker"
if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    echo "Creating ZFS dataset '$POOL/$DATASET'..."
    zfs create "$POOL/$DATASET"
    echo "✅ Dataset '$POOL/$DATASET' created."
fi

# ------------------------------
# Export selected pool for use in bootstrap / LXC scripts
# ------------------------------
export ZFS_POOL="$POOL"
echo "✅ ZFS setup completed using pool: $ZFS_POOL"
