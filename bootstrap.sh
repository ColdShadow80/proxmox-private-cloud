#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts"
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"

# ------------------------------
# Fetch script safely
# ------------------------------
fetch_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    local local_path="$SCRIPT_DIR/$script_name"

    # Download silently
    curl -fsSL "$url" -o "$local_path"
    if [ ! -f "$local_path" ]; then
        echo "ERROR: Failed to download $script_name" >&2
        exit 1
    fi
    echo "✅ Successfully downloaded $script_name" >&2  # log to stderr

    # Return only the path
    printf '%s' "$local_path"
}

# ------------------------------
# Run script (source or bash)
# ------------------------------
run_script() {
    local script_path="$1"
    local mode="${2:-bash}"

    echo ""
    echo "------------------------------"
    echo "Running script: $(basename "$script_path")"
    echo "------------------------------"

    if [ "$mode" = "source" ]; then
        source "$script_path"
    else
        bash "$script_path"
    fi
}

# ------------------------------
# Step 1: ZFS setup
# ------------------------------
ZFS_SCRIPT=$(fetch_script "02-create-zfs.sh")
run_script "$ZFS_SCRIPT" source

export ZFS_POOL="$POOL"
echo "✅ ZFS_POOL set to $ZFS_POOL"

# ------------------------------
# Step 2: Determine starting CTID
# ------------------------------
read -p 'Do you want to specify a starting container ID? [y/N]: ' START_CID_ANSWER
if [[ "$START_CID_ANSWER" =~ ^[Yy]$ ]]; then
    read -p 'Enter starting CTID number: ' START_CID
else
    START_CID=100
fi
echo "Starting CTID set to: $START_CID"

# ------------------------------
# Step 3: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
export START_CID
run_script "$CTID_SCRIPT" source
echo "Next available CTID(s) to be used: $CTID"

# ------------------------------
# Step 4: LXC creation
# ------------------------------
LXC_SCRIPT="$SCRIPT_DIR/03-create-lxc.sh"

# Overwrite 03-create-lxc.sh with safe template handling
cat > "$LXC_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Creating LXC container(s)..."
echo "------------------------------"

CTID=${START_CID:-${CTID:-100}}
echo "Using starting CTID: $CTID"

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

# Ensure template exists
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64"
if ! pveam list | grep -q "$TEMPLATE_NAME"; then
    echo "ERROR: Template $TEMPLATE_NAME not found!"
    exit 1
fi

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
EOF

chmod +x "$LXC_SCRIPT"
run_script "$LXC_SCRIPT"
