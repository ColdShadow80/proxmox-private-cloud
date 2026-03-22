#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Installing Paperless-ngx..."
echo "------------------------------"
echo ""
echo "Usage: $0 [--with-ai]"
echo "  --with-ai   Also deploy Ollama, Open WebUI, Paperless-AI, and Paperless-GPT"
echo ""
echo "Reference: https://technotim.com/posts/paperless-ngx-local-ai/"
echo ""

INSTALL_AI=false
for arg in "$@"; do
  case "$arg" in
    --with-ai) INSTALL_AI=true ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Run 05-install-docker.sh first."
    exit 1
fi

# Skip reinstall if paperless-ngx already exists
if docker ps -a --format '{{.Names}}' | grep -Eq '^paperless-ngx$'; then
  echo "Paperless-ngx container already exists. Ensuring it's running..."
  docker compose --env-file /opt/apps/paperless/.env \
    -f /opt/apps/paperless/docker-compose.yml up -d
  echo "✅ Paperless-ngx is ready."
  echo ""
  echo "   To add AI services to an existing install:"
  echo "   1. Re-run with --with-ai on a clean install, or"
  echo "   2. Manually append AI services to /opt/apps/paperless/docker-compose.yml"
  exit 0
fi

APP_DIR="/opt/apps/paperless"
mkdir -p "$APP_DIR"

# Generate secrets on first install; preserve them on upgrades
PAPERLESS_SECRET_KEY=""
POSTGRES_PASSWORD=""
PAPERLESS_ADMIN_PASSWORD=""

if [ -f "$APP_DIR/.env" ]; then
  PAPERLESS_SECRET_KEY=$(grep '^PAPERLESS_SECRET_KEY=' "$APP_DIR/.env" | head -n1 | cut -d'=' -f2- || true)
  POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$APP_DIR/.env" | head -n1 | cut -d'=' -f2- || true)
  PAPERLESS_ADMIN_PASSWORD=$(grep '^PAPERLESS_ADMIN_PASSWORD=' "$APP_DIR/.env" | head -n1 | cut -d'=' -f2- || true)
fi

if [ -z "$PAPERLESS_SECRET_KEY" ]; then
  PAPERLESS_SECRET_KEY=$(openssl rand -hex 32)
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  POSTGRES_PASSWORD=$(openssl rand -hex 16)
fi

if [ -z "$PAPERLESS_ADMIN_PASSWORD" ]; then
  PAPERLESS_ADMIN_PASSWORD=$(openssl rand -hex 8)
fi

# Write .env — bash expansion intentional here for secret injection
cat > "$APP_DIR/.env" <<EOF
TZ=UTC
POSTGRES_DB=paperless
POSTGRES_USER=paperless
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
PAPERLESS_SECRET_KEY=${PAPERLESS_SECRET_KEY}
PAPERLESS_REDIS=redis://paperless-redis:6379
PAPERLESS_DBHOST=paperless-postgres
PAPERLESS_DBNAME=paperless
PAPERLESS_DBUSER=paperless
PAPERLESS_DBPASS=${POSTGRES_PASSWORD}
PAPERLESS_TIKA_ENABLED=1
PAPERLESS_TIKA_GOTENBERG_ENDPOINT=http://paperless-gotenberg:3000
PAPERLESS_TIKA_ENDPOINT=http://paperless-tika:9998
PAPERLESS_ALLOWED_HOSTS=*
PAPERLESS_ADMIN_USER=admin
PAPERLESS_ADMIN_PASSWORD=${PAPERLESS_ADMIN_PASSWORD}
PAPERLESS_ADMIN_MAIL=admin@localhost
EOF

# Build docker-compose.yml — single quotes on heredoc delimiters prevent bash expansion
{
cat <<'BASE_EOF'
services:
  paperless-ngx:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless-ngx
    restart: unless-stopped
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      - paperless-postgres
      - paperless-redis
      - paperless-gotenberg
      - paperless-tika
    volumes:
      - ./data:/usr/src/paperless/data
      - ./media:/usr/src/paperless/media
      - ./export:/usr/src/paperless/export
      - ./consume:/usr/src/paperless/consume

  paperless-postgres:
    image: postgres:17-alpine
    container_name: paperless-postgres
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./postgres:/var/lib/postgresql/data

  paperless-redis:
    image: redis:8-alpine
    container_name: paperless-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data

  paperless-gotenberg:
    image: gotenberg/gotenberg:8
    container_name: paperless-gotenberg
    restart: unless-stopped
    command:
      - "gotenberg"
      - "--chromium-disable-javascript=true"
      - "--chromium-allow-list=file:///tmp/.*"

  paperless-tika:
    image: apache/tika:latest
    container_name: paperless-tika
    restart: unless-stopped
BASE_EOF

if [ "$INSTALL_AI" = "true" ]; then
cat <<'AI_EOF'

  # -- Local AI services (optional, enabled with --with-ai) --

  paperless-ollama:
    image: ollama/ollama:latest
    container_name: paperless-ollama
    restart: unless-stopped
    volumes:
      - ./ollama:/root/.ollama
    # Uncomment to enable NVIDIA GPU acceleration:
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: all
    #           capabilities: [gpu]

  paperless-openwebui:
    image: ghcr.io/open-webui/open-webui:latest
    container_name: paperless-openwebui
    restart: unless-stopped
    depends_on:
      - paperless-ollama
    ports:
      - "3010:8080"
    environment:
      OLLAMA_BASE_URL: http://paperless-ollama:11434
    volumes:
      - ./open-webui:/app/backend/data

  paperless-ai:
    image: clusterzx/paperless-ai:latest
    container_name: paperless-ai
    restart: unless-stopped
    depends_on:
      - paperless-ollama
      - paperless-ngx
    ports:
      - "3020:3000"
    environment:
      PAPERLESS_API_URL: http://paperless-ngx:8000/api
      PAPERLESS_URL: http://paperless-ngx:8000
      PAPERLESS_API_TOKEN: "REPLACE_WITH_PAPERLESS_API_TOKEN"
      PAPERLESS_USERNAME: admin
      AI_PROVIDER: ollama
      OLLAMA_API_URL: http://paperless-ollama:11434
      OLLAMA_MODEL: llama3.2:3b
      SCAN_INTERVAL: "*/30 * * * *"
    volumes:
      - ./paperless-ai:/app/data

  paperless-gpt:
    image: icereed/paperless-gpt:latest
    container_name: paperless-gpt
    restart: unless-stopped
    depends_on:
      - paperless-ollama
      - paperless-ngx
    ports:
      - "3030:8080"
    environment:
      PAPERLESS_BASE_URL: http://paperless-ngx:8000
      PAPERLESS_API_TOKEN: "REPLACE_WITH_PAPERLESS_API_TOKEN"
      LLM_PROVIDER: ollama
      OLLAMA_HOST: http://paperless-ollama:11434
      LLM_MODEL: llama3.2:3b
      VISION_LLM_PROVIDER: ollama
      VISION_LLM_MODEL: minicpm-v:8b
      AUTO_OCR_TAG: paperless-gpt-ocr-auto
      AUTO_TAG: paperless-gpt-auto
    volumes:
      - ./paperless-gpt/prompts:/app/prompts
AI_EOF
fi

} > "$APP_DIR/docker-compose.yml"

# Create consume directory so document drops work immediately
mkdir -p "$APP_DIR/consume"

docker compose --env-file "$APP_DIR/.env" -f "$APP_DIR/docker-compose.yml" up -d

echo ""
echo "✅ Paperless-ngx installed!"
echo "   Web UI:   http://<container-ip>:8000"
echo "   Login:    admin / ${PAPERLESS_ADMIN_PASSWORD}"
echo ""
echo "   Drop documents to consume:  $APP_DIR/consume/"
echo "   Credentials saved in:       $APP_DIR/.env"

if [ "$INSTALL_AI" = "true" ]; then
  echo ""
  echo "   AI Services:"
  echo "   Open WebUI:    http://<container-ip>:3010  (model manager)"
  echo "   Paperless-AI:  http://<container-ip>:3020  (metadata suggestions)"
  echo "   Paperless-GPT: http://<container-ip>:3030  (vision OCR)"
  echo ""
  echo "   Next steps to activate AI:"
  echo "   1. Open WebUI → Pull models: llama3.2:3b and minicpm-v:8b"
  echo "   2. Paperless UI → Profile → API Tokens → Generate token"
  echo "   3. Replace REPLACE_WITH_PAPERLESS_API_TOKEN in:"
  echo "      $APP_DIR/docker-compose.yml (paperless-ai and paperless-gpt)"
  echo "   4. Restart AI services:"
  echo "      docker compose -f $APP_DIR/docker-compose.yml restart paperless-ai paperless-gpt"
fi
