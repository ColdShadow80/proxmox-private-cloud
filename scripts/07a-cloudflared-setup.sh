#!/usr/bin/env bash
set -e

# Optional automated Cloudflare Tunnel setup
# This script is safe to run after 07-configure-cloudflare.sh

CTID=$(cat /tmp/homelab_ctid)
CONFIG_DIR="/root/.cloudflared"
CREDENTIALS_FILE="$CONFIG_DIR/homelab-tunnel.json"
DOMAIN_FILE="/opt/gitops/cloudflared-domain.txt"

# Ask the user for the domain
echo "Enter the domain or subdomain you want to use for Cloudflare Tunnel (e.g., homelab.example.com)"
echo "If you leave it empty, a free .trycloudflare.com subdomain will be used:"
read -r USER_DOMAIN

# Prepare config directory inside the container
pct exec $CTID -- mkdir -p $CONFIG_DIR

# Check if tunnel already exists
TUNNEL_EXISTS=$(pct exec $CTID -- bash -c "cloudflared tunnel list | grep homelab || true")

if [ -z "$TUNNEL_EXISTS" ]; then
    echo "Creating Cloudflare tunnel named 'homelab'..."
    pct exec $CTID -- bash -c "
        cloudflared tunnel create homelab --output $CREDENTIALS_FILE
    "
else
    echo "Tunnel 'homelab' already exists, skipping creation."
fi

# Determine hostname
if [ -z "$USER_DOMAIN" ]; then
    # use free trycloudflare.com subdomain
    HOSTNAME=$(pct exec $CTID -- bash -c "cloudflared tunnel route dns homelab | awk '{print \$1}' || echo homelab.trycloudflare.com")
else
    HOSTNAME="$USER_DOMAIN"
fi

# Save hostname for later reference
pct exec $CTID -- bash -c "echo '$HOSTNAME' > $DOMAIN_FILE"

# Create cloudflared config.yml
CONFIG_YML="$CONFIG_DIR/config.yml"
pct exec $CTID -- bash -c "
cat <<EOF > $CONFIG_YML
tunnel: homelab
credentials-file: $CREDENTIALS_FILE

ingress:
  - hostname: dockhand.$HOSTNAME
    service: http://docker-host:3000
  - hostname: traefik.$HOSTNAME
    service: http://docker-host:8080
  - hostname: dashboard.$HOSTNAME
    service: http://docker-host:9000
  - service: http_status:404
EOF
"

# Start the container
pct exec $CTID -- bash -c "
docker rm -f cloudflared || true
docker run -d \
  --name cloudflared \
  --restart unless-stopped \
  -v $CONFIG_DIR:/etc/cloudflared \
  cloudflare/cloudflared:latest tunnel --config /etc/cloudflared/config.yml run homelab
"

echo ""
echo "Cloudflare Tunnel setup completed!"
echo "You can access your services at the following addresses:"
echo "Dockhand: https://dockhand.$HOSTNAME"
echo "Traefik: https://traefik.$HOSTNAME"
echo "Dashboard: https://dashboard.$HOSTNAME"
echo ""
echo "The tunnel hostname has been saved in $DOMAIN_FILE inside the container."
