#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Installing Homarr..."
echo "------------------------------"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Run 05-install-docker.sh first."
    exit 1
fi

APP_DIR="/opt/apps/homarr"
mkdir -p "$APP_DIR"

if ! command -v jq >/dev/null 2>&1; then
  echo "Installing jq..."
  apt-get update >/dev/null
  apt-get install -y jq >/dev/null
fi

if ! command -v cron >/dev/null 2>&1; then
  echo "Installing cron..."
  apt-get update >/dev/null
  apt-get install -y cron >/dev/null
fi

SECRET_ENCRYPTION_KEY=""
HOMARR_API_KEY=""
if [ -f "$APP_DIR/.env" ]; then
  SECRET_ENCRYPTION_KEY=$(grep '^SECRET_ENCRYPTION_KEY=' "$APP_DIR/.env" | head -n1 | cut -d'=' -f2- || true)
  HOMARR_API_KEY=$(grep '^HOMARR_API_KEY=' "$APP_DIR/.env" | head -n1 | cut -d'=' -f2- || true)
fi

if [ -z "$SECRET_ENCRYPTION_KEY" ]; then
  SECRET_ENCRYPTION_KEY=$(openssl rand -hex 32)
fi

cat > "$APP_DIR/.env" <<EOF
SECRET_ENCRYPTION_KEY=$SECRET_ENCRYPTION_KEY
HOMARR_API_KEY=$HOMARR_API_KEY
EOF

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  homarr:
    image: ghcr.io/homarr-labs/homarr:latest
    container_name: homarr
    restart: unless-stopped
    ports:
      - "7575:7575"
    env_file:
      - .env
    volumes:
      - ./appdata:/appdata
      - /var/run/docker.sock:/var/run/docker.sock:ro
EOF

cat > "$APP_DIR/homarr-autosync.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/apps/homarr"
ENV_FILE="$APP_DIR/.env"
HOMARR_URL="${HOMARR_URL:-http://127.0.0.1:7575}"
HOMARR_APP_HOST="${HOMARR_APP_HOST:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
DEFAULT_ICON_URL="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@master/svg/homarr.svg"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [ -z "${HOMARR_API_KEY:-}" ]; then
  echo "[homarr-autosync] HOMARR_API_KEY is empty in $ENV_FILE. Skipping sync."
  exit 0
fi

if ! docker ps >/dev/null 2>&1; then
  echo "[homarr-autosync] Docker is unavailable."
  exit 1
fi

if ! curl -fsS "$HOMARR_URL/api/health/ready" >/dev/null 2>&1; then
  echo "[homarr-autosync] Homarr is not ready at $HOMARR_URL."
  exit 1
fi

EXISTING_NAMES=$(
  curl -fsS \
    -H "ApiKey: $HOMARR_API_KEY" \
    "$HOMARR_URL/api/apps" | jq -r '.[].name // empty' 2>/dev/null || true
)

if [ -z "$EXISTING_NAMES" ]; then
  status_code=$(curl -s -o /dev/null -w '%{http_code}' -H "ApiKey: $HOMARR_API_KEY" "$HOMARR_URL/api/apps" || true)
  echo "[homarr-autosync] Could not read existing apps from $HOMARR_URL/api/apps (HTTP $status_code). Verify HOMARR_API_KEY and Homarr version."
fi

added_count=0

while IFS= read -r container_id; do
  name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's#^/##')

  if [ "$name" = "homarr" ]; then
    continue
  fi

  hide_label=$(docker inspect --format '{{ index .Config.Labels "homarr.hide" }}' "$container_id" 2>/dev/null || true)
  if [ -n "$hide_label" ] && [ "$hide_label" != "<no value>" ]; then
    continue
  fi

  if printf '%s\n' "$EXISTING_NAMES" | grep -Fxq "$name"; then
    continue
  fi

  port=$(docker inspect "$container_id" | jq -r '.[0].NetworkSettings.Ports | to_entries[]? | .value[0].HostPort' | head -n1)
  if [ -z "$port" ] || [ "$port" = "null" ]; then
    continue
  fi

  app_url="http://$HOMARR_APP_HOST:$port"

  payload=$(jq -n \
    --arg name "$name" \
    --arg href "$app_url" \
    --arg icon "$DEFAULT_ICON_URL" \
    '{name: $name, description: "Auto-discovered from Docker", iconUrl: $icon, href: $href, pingUrl: null}')

  if curl -fsS -X POST \
    -H "Content-Type: application/json" \
    -H "ApiKey: $HOMARR_API_KEY" \
    -d "$payload" \
    "$HOMARR_URL/api/apps" >/dev/null 2>&1; then
    echo "[homarr-autosync] Added app: $name -> $app_url"
    EXISTING_NAMES=$(printf '%s\n%s\n' "$EXISTING_NAMES" "$name" | sed '/^$/d')
    added_count=$((added_count + 1))
  fi
done < <(docker ps --format '{{.ID}}')

echo "[homarr-autosync] Completed. Added $added_count new app(s)."
EOF

chmod +x "$APP_DIR/homarr-autosync.sh"

cat > /etc/cron.d/homarr-autosync <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

*/15 * * * * root /opt/apps/homarr/homarr-autosync.sh >> /var/log/homarr-autosync.log 2>&1
EOF

chmod 0644 /etc/cron.d/homarr-autosync
systemctl enable cron >/dev/null 2>&1 || true
systemctl restart cron >/dev/null 2>&1 || true

docker compose -f "$APP_DIR/docker-compose.yml" up -d

echo "Running initial Homarr autosync..."
"$APP_DIR/homarr-autosync.sh" || true

echo "✅ Homarr installed at http://<container-ip>:7575"
echo "ℹ️ Set HOMARR_API_KEY in $APP_DIR/.env to enable full auto-population."
echo "ℹ️ Scheduled scan runs every 15 minutes (see /etc/cron.d/homarr-autosync)."
