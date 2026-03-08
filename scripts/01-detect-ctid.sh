#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Detecting next free CTID(s)..."
echo "------------------------------"

# Get all used CTIDs
USED_CTIDS=($(pct list 2>/dev/null | awk 'NR>1 {print $1}'))
MAX_CTID=999
NUM_CONTAINERS=1  # Can adjust if deploying multiple containers

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
    START_CTID=100
fi

# Find the next free CTIDs starting from START_CTID
FREE_CTIDS=()
candidate=$START_CTID
while [ ${#FREE_CTIDS[@]} -lt "$NUM_CONTAINERS" ] && [ "$candidate" -le "$MAX_CTID" ]; do
    if ! [[ " ${USED_CTIDS[@]} " =~ " $candidate " ]]; then
        FREE_CTIDS+=($candidate)
    fi
    ((candidate++))
done

if [ ${#FREE_CTIDS[@]} -eq 0 ]; then
    echo "ERROR: No free CTID found starting from $START_CTID"
    exit 1
fi

echo "Next available container ID(s) to be used: ${FREE_CTIDS[@]}"
export CTID="${FREE_CTIDS[0]}"
