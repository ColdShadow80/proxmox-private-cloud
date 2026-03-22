#!/usr/bin/env bash
set -e

echo "=============================="
echo "Starting Proxmox GitOps Homelab Deployment..."
echo "=============================="

REPO_REF="${REPO_REF:-main}"
BASE_URL="https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/${REPO_REF}/scripts"
SCRIPT_DIR="/tmp/proxmox-scripts"
mkdir -p "$SCRIPT_DIR"
echo "Temporary script directory: $SCRIPT_DIR"
echo "Using repository ref: $REPO_REF"

# ------------------------------
# Optional app selection (default: No)
# ------------------------------
echo ""
echo "------------------------------"
echo "Optional app selection"
echo "------------------------------"
read -rp "Install Uptime Kuma? [y/N]: " INSTALL_UPTIME_ANSWER
read -rp "Install Homarr? [y/N]: " INSTALL_HOMARR_ANSWER
read -rp "Install Immich? [y/N]: " INSTALL_IMMICH_ANSWER

INSTALL_UPTIME="false"
INSTALL_HOMARR="false"
INSTALL_IMMICH="false"

if [[ "$INSTALL_UPTIME_ANSWER" =~ ^[Yy]$ ]]; then INSTALL_UPTIME="true"; fi
if [[ "$INSTALL_HOMARR_ANSWER" =~ ^[Yy]$ ]]; then INSTALL_HOMARR="true"; fi
if [[ "$INSTALL_IMMICH_ANSWER" =~ ^[Yy]$ ]]; then INSTALL_IMMICH="true"; fi

# ------------------------------
# Function to fetch scripts safely
# ------------------------------
fetch_script() {
    local script_name="$1"
    local url="$BASE_URL/$script_name"
    local local_path="$SCRIPT_DIR/$script_name"

    echo "" >&2
    echo "------------------------------" >&2
    echo "Fetching script: $script_name" >&2
    echo "URL: $url" >&2
    echo "------------------------------" >&2

    # Download script
    curl -fsSL "$url" -o "$local_path"

    # Verify file exists
    if [ ! -f "$local_path" ]; then
        echo "ERROR: Failed to download $script_name" >&2
        exit 1
    fi

    # Fix line endings to Unix style
    if command -v dos2unix >/dev/null 2>&1; then
        dos2unix "$local_path" &>/dev/null || true
    fi

    # Make executable
    chmod +x "$local_path"

    echo "✅ Successfully downloaded and made executable: $script_name" >&2
    printf '%s\n' "$local_path"
}

# ------------------------------
# Function to run a script (bash or source)
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

# ------------------------------
# Step 2: Detect next free CTID
# ------------------------------
CTID_SCRIPT=$(fetch_script "01-detect-ctid.sh")
run_script "$CTID_SCRIPT" source
echo "Next available CTID(s) to be used: $CTID"

# ------------------------------
# Step 3: LXC creation
# ------------------------------
LXC_SCRIPT=$(fetch_script "03-create-lxc.sh")
export ZFS_POOL
export CTID
run_script "$LXC_SCRIPT" bash

# ------------------------------
# Step 4: Configure network (optional - runs on host)
# ------------------------------
echo ""
echo "------------------------------"
echo "Step 4: Network configuration"
echo "------------------------------"
read -rp "Do you want to configure static IP for container $CTID? [y/N]: " configure_network
if [[ "$configure_network" =~ ^[Yy]$ ]]; then
    read -rp "Enter static IP (e.g., 192.168.1.50/24): " STATIC_IP
    read -rp "Enter gateway (e.g., 192.168.1.1): " GATEWAY
    echo "Configuring network for container $CTID..."
    pct set "$CTID" --net0 "name=eth0,bridge=vmbr0,ip=$STATIC_IP,gw=$GATEWAY"
    echo "✅ Network configured with IP: $STATIC_IP"
else
    echo "Skipping static IP configuration (using DHCP)."
fi

# ------------------------------
# Step 5: Install Docker inside container
# ------------------------------
echo ""
echo "------------------------------"
echo "Step 5: Installing Docker..."
echo "------------------------------"
DOCKER_SCRIPT=$(fetch_script "05-install-docker.sh")
echo "Copying Docker install script to container $CTID..."
pct push "$CTID" "$DOCKER_SCRIPT" /tmp/05-install-docker.sh
echo "Executing Docker installation inside container..."
pct exec "$CTID" -- bash /tmp/05-install-docker.sh
echo "✅ Docker installed in container $CTID"

# ------------------------------
# Step 6: Deploy GitOps stack
# ------------------------------
echo ""
echo "------------------------------"
echo "Step 6: Deploying GitOps stack..."
echo "------------------------------"
GITOPS_SCRIPT=$(fetch_script "06-deploy-gitops.sh")
echo "Copying GitOps deployment script to container $CTID..."
pct push "$CTID" "$GITOPS_SCRIPT" /tmp/06-deploy-gitops.sh
echo "Executing GitOps deployment inside container..."
pct exec "$CTID" -- bash /tmp/06-deploy-gitops.sh
echo "✅ GitOps stack deployed in container $CTID"

# ------------------------------
# Step 7: Configure Cloudflare Tunnel (optional)
# ------------------------------
echo ""
echo "------------------------------"
echo "Step 7: Cloudflare Tunnel setup"
echo "------------------------------"
read -rp "Do you want to configure Cloudflare Tunnel? [y/N]: " configure_cloudflare
if [[ "$configure_cloudflare" =~ ^[Yy]$ ]]; then
    CLOUDFLARE_SCRIPT=$(fetch_script "07-configure-cloudflare.sh")
    echo "Copying Cloudflare script to container $CTID..."
    pct push "$CTID" "$CLOUDFLARE_SCRIPT" /tmp/07-configure-cloudflare.sh
    echo "Executing Cloudflare setup inside container..."
    pct exec "$CTID" -- bash /tmp/07-configure-cloudflare.sh
    echo "✅ Cloudflare Tunnel configured"
else
    echo "Skipping Cloudflare Tunnel configuration."
fi

# ------------------------------
# Step 8: Deploy Dashboard
# ------------------------------
echo ""
echo "------------------------------"
echo "Step 8: Deploying Dashboard..."
echo "------------------------------"
DASHBOARD_SCRIPT=$(fetch_script "08-deploy-dashboard.sh")
echo "Copying Dashboard deployment script to container $CTID..."
pct push "$CTID" "$DASHBOARD_SCRIPT" /tmp/08-deploy-dashboard.sh
echo "Executing Dashboard deployment inside container..."
pct exec "$CTID" -- bash /tmp/08-deploy-dashboard.sh
echo "✅ Dashboard step completed in container $CTID"

# ------------------------------
# Step 9: Install Uptime Kuma
# ------------------------------
if [ "$INSTALL_UPTIME" = "true" ]; then
    echo ""
    echo "------------------------------"
    echo "Step 9: Installing Uptime Kuma..."
    echo "------------------------------"
    UPTIME_SCRIPT=$(fetch_script "10-install-uptime-kuma.sh")
    echo "Copying Uptime Kuma script to container $CTID..."
    pct push "$CTID" "$UPTIME_SCRIPT" /tmp/10-install-uptime-kuma.sh
    echo "Executing Uptime Kuma installation inside container..."
    pct exec "$CTID" -- bash /tmp/10-install-uptime-kuma.sh
    echo "✅ Uptime Kuma installation step completed"
else
    echo "Skipping Uptime Kuma installation."
fi

# ------------------------------
# Step 10: Install Homarr
# ------------------------------
if [ "$INSTALL_HOMARR" = "true" ]; then
    echo ""
    echo "------------------------------"
    echo "Step 10: Installing Homarr..."
    echo "------------------------------"
    HOMARR_SCRIPT=$(fetch_script "11-install-homarr.sh")
    echo "Copying Homarr script to container $CTID..."
    pct push "$CTID" "$HOMARR_SCRIPT" /tmp/11-install-homarr.sh
    echo "Executing Homarr installation inside container..."
    pct exec "$CTID" -- bash /tmp/11-install-homarr.sh
    echo "✅ Homarr installation step completed"
else
    echo "Skipping Homarr installation."
fi

# ------------------------------
# Step 11: Install Immich
# ------------------------------
if [ "$INSTALL_IMMICH" = "true" ]; then
    echo ""
    echo "------------------------------"
    echo "Step 11: Installing Immich..."
    echo "------------------------------"
    IMMICH_SCRIPT=$(fetch_script "12-install-immich.sh")
    echo "Copying Immich script to container $CTID..."
    pct push "$CTID" "$IMMICH_SCRIPT" /tmp/12-install-immich.sh
    echo "Executing Immich installation inside container..."
    pct exec "$CTID" -- bash /tmp/12-install-immich.sh
    echo "✅ Immich installation step completed"
else
    echo "Skipping Immich installation."
fi

# ------------------------------
# Step 12: Summary
# ------------------------------
echo ""
echo "=============================="
echo "Deployment Summary"
echo "=============================="
export INSTALL_UPTIME
export INSTALL_HOMARR
export INSTALL_IMMICH
SUMMARY_SCRIPT=$(fetch_script "09-summary.sh")
run_script "$SUMMARY_SCRIPT" bash

echo ""
echo "=============================="
echo "✅ Proxmox GitOps Homelab Deployment Complete!"
echo "=============================="
