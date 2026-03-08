#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Running embedded ZFS setup..."
echo "------------------------------"

# List available pools
POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}

# Function to display pool info
display_pools() {
    echo "Available ZFS pools:"
    for i in "${!POOLS[@]}"; do
        zpool status "${POOLS[$i]}" | awk 'NR==1 || NR==2 {print}'
        echo "Index: $i, Name: ${POOLS[$i]}"
        echo "------------------------------"
    done
}

if [ "$NUM_POOLS" -eq 0 ]; then
    echo "ERROR: No ZFS pools found!"
    exit 1
elif [ "$NUM_POOLS" -eq 1 ]; then
    POOL="${POOLS[0]}"
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    echo "Multiple ZFS pools detected. Please select one to use:"
    display_pools
    read -p "Enter the index number of the pool to use: " POOL_IDX
    POOL="${POOLS[$POOL_IDX]}"
    echo "Selected pool: $POOL"
fi

DATASET=docker

if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    echo "Creating dataset '$POOL/$DATASET'..."
    zfs create "$POOL/$DATASET"
fi

export ZFS_POOL="$POOL"
echo "✅ ZFS setup completed using pool: $ZFS_POOL"
