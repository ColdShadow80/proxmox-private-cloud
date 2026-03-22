#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Installing Immich..."
echo "------------------------------"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Run 05-install-docker.sh first."
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -Eq '^(immich|immich-server)$'; then
  echo "Immich container already exists. Ensuring it's running..."
  docker start immich >/dev/null 2>&1 || true
  docker start immich-server >/dev/null 2>&1 || true
  echo "✅ Immich is ready."
  exit 0
fi

APP_DIR="/opt/apps/immich"
mkdir -p "$APP_DIR"

cat > "$APP_DIR/.env" <<'EOF'
POSTGRES_DB=immich
POSTGRES_USER=immich
POSTGRES_PASSWORD=immich
EOF

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    ports:
      - "2283:2283"
    volumes:
      - ./photos:/usr/src/app/upload
    environment:
      DB_HOSTNAME: immich-postgres
      DB_USERNAME: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_DATABASE_NAME: ${POSTGRES_DB}
      REDIS_HOSTNAME: immich-redis
    depends_on:
      - immich-redis
      - immich-postgres

  immich-redis:
    image: redis:7-alpine
    container_name: immich-redis
    restart: unless-stopped

  immich-postgres:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    container_name: immich-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - ./postgres:/var/lib/postgresql/data
EOF

docker compose --env-file "$APP_DIR/.env" -f "$APP_DIR/docker-compose.yml" up -d
echo "✅ Immich installed at http://<container-ip>:2283"
