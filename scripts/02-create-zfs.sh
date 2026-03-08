#!/usr/bin/env bash
set -euo pipefail

echo "------------------------------"
echo "Running embedded ZFS setup..."
echo "------------------------------"

# Function to display ZFS pool information
show_pools_info() {
    echo "Available ZFS pools:"
    printf "%-3s %-20s %-10s %-10s %-10s %-10s\n" "No" "Pool" "Size" "Allocated" "Free" "Health"
    local i=1
    for pool in "${POOLS[@]}"; do
        local size allocated free health
        size=$(zpool list -H -o size "$pool")
        allocated=$(zpool list -H -o allocated "$pool")
        free=$(zpool list -H -o free "$pool")
        health=$(zpool list -H -o health "$pool")
        printf "%-3s %-20s %-10s %-10s %-10s %-10s\n" "$i" "$pool" "$size" "$allocated" "$free" "$health"
        ((i++))
    done
}

# List all available ZFS pools
POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}

if [ "$NUM_POOLS" -eq 0 ]; then
    echo "ERROR: No ZFS pools detected. Please create a pool first."
    exit 1
elif [ "$NUM_POOLS" -eq 1 ]; then
    POOL="${POOLS[0]}"
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    # Show pool info before selection
    show_pools_info
    echo ""
    echo "Multiple ZFS pools detected. Please select one to use:"
    select POOL in "${POOLS[@]}"; do
        if [ -n "$POOL" ]; then
            echo "Selected ZFS pool: $POOL"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

# Dataset name
DATASET="docker"

# Check if dataset exists
if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    echo "Creating ZFS dataset '$POOL/$DATASET'..."
    zfs create "$POOL/$DATASET"
fi

# Export pool for use by other scripts
export POOL
export ZFS_POOL="$POOL"
echo "✅ ZFS setup completed using pool: $ZFS_POOL"
