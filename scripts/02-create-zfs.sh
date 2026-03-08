#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Checking available ZFS pools..."
echo "------------------------------"

# Detect all online ZFS pools
POOLS=($(zpool list -H -o name))
NUM_POOLS=${#POOLS[@]}

if [ "$NUM_POOLS" -eq 0 ]; then
    echo "ERROR: No ZFS pools detected on this server."
    echo "A ZFS pool is required to create the Docker dataset."
    echo "Please create a ZFS pool first and re-run this script."
    exit 1
fi

# Function to display pool info
show_pool_info() {
    local index=$1
    local name=$2
    local size_free=$(zpool list -H -o size,free "$name")
    local size=$(echo $size_free | awk '{print $1}')
    local free=$(echo $size_free | awk '{print $2}')
    echo "$index) $name — Size: $size, Free: $free"
}

# Select pool
if [ "$NUM_POOLS" -eq 1 ]; then
    POOL="${POOLS[0]}"
    echo "Only one ZFS pool found. Using pool: $POOL"
else
    echo "Multiple ZFS pools detected. Please select one to use:"
    for i in "${!POOLS[@]}"; do
        show_pool_info $((i+1)) "${POOLS[$i]}"
    done

    while true; do
        read -rp "Enter the number of the pool to use: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$NUM_POOLS" ]; then
            POOL="${POOLS[$((selection-1))]}"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and $NUM_POOLS."
        fi
    done
    echo "You selected ZFS pool: $POOL"
fi

# Create Docker dataset if it does not exist
DATASET=docker
if zfs list "$POOL/$DATASET" &>/dev/null; then
    echo "ZFS dataset '$POOL/$DATASET' already exists."
else
    echo "Creating ZFS dataset '$POOL/$DATASET'..."
    zfs create "$POOL/$DATASET"
    echo "ZFS dataset created: $POOL/$DATASET"
fi

export POOL
echo "✅ ZFS setup completed using pool: $POOL"
