#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Installing Uptime Kuma..."
echo "------------------------------"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Run 05-install-docker.sh first."
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx 'uptime-kuma'; then
    echo "Uptime Kuma container already exists. Ensuring it's running..."
    docker start uptime-kuma >/dev/null 2>&1 || true
    echo "✅ Uptime Kuma is ready."
    exit 0
fi

APP_DIR="/opt/apps/uptime-kuma"
mkdir -p "$APP_DIR"

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
EOF

docker compose -f "$APP_DIR/docker-compose.yml" up -d
echo "✅ Uptime Kuma installed at http://<container-ip>:3001"
