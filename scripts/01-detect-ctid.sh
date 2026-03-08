#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Detecting next free CTID(s)..."
echo "------------------------------"

# Function to get all used CTIDs
get_used_ctids() {
    pct list 2>/dev/null | awk 'NR>1 {print $1}'
}

USED_CTIDS=($(get_used_ctids))
MAX_CTID=999
NUM_CONTAINERS=1  # Change this if you plan to deploy multiple at once

# Ask user if they want to set a starting CTID
read -rp "Do you want to set a starting container/VM number? [y/N]: " use_start

if [[ "$use_start" =~ ^[Yy]$ ]]; then
    while true; do
        read -rp "Enter the starting CTID number (e.g., 100): " START_CTID
        if [[ "$START_CTID" =~ ^[0-9]+$ ]] && [ "$START_CTID" -ge 100 ] && [ "$START_CTID" -le "$MAX_CTID" ]; then
            break
        else
            echo "Invalid number. Please enter a number between 100 and $MAX_CTID."
        fi
    done
else
    # Default behavior: find first free CTID starting from 100
    START_CTID=100
fi

# Function to find the next free CTID starting from START_CTID
find_next_free_ctids() {
    local start=$1
    local needed=$2
    local ctids=()
    local candidate=$start

    while [ ${#ctids[@]} -lt "$needed" ] && [ "$candidate" -le "$MAX_CTID" ]; do
        if ! [[ " ${USED_CTIDS[@]} " =~ " $candidate " ]]; then
            ctids+=($candidate)
        fi
        ((candidate++))
    done

    echo "${ctids[@]}"
}

FREE_CTIDS=($(find_next_free_ctids $START_CTID $NUM_CONTAINERS))

if [ ${#FREE_CTIDS[@]} -eq 0 ]; then
    echo "ERROR: No free CTID found starting from $START_CTID"
    exit 1
fi

echo "Next available container ID(s) to be used: ${FREE_CTIDS[@]}"
export CTID="${FREE_CTIDS[0]}"  # Export the first one for bootstrap
