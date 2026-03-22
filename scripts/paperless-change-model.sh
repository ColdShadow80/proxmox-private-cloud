#!/usr/bin/env bash
# =============================================================================
# paperless-change-model.sh — Change Ollama models used by Paperless AI services
# =============================================================================
# Usage:
#   bash paperless-change-model.sh --text <model>              # Change text model
#   bash paperless-change-model.sh --vision <model>            # Change vision model
#   bash paperless-change-model.sh --text <model> --vision <model>  # Change both
#   bash paperless-change-model.sh --list                      # List pulled models
#
# Examples:
#   bash paperless-change-model.sh --text deepseek-r1:7b
#   bash paperless-change-model.sh --text qwen2.5:7b --vision minicpm-v:8b
#   bash paperless-change-model.sh --list
# =============================================================================

set -euo pipefail

APP_DIR="${PAPERLESS_DIR:-/opt/apps/paperless}"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

TEXT_MODEL=""
VISION_MODEL=""
DO_LIST=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -eq 0 ]; then
  echo "Usage:"
  echo "  $0 --text <model>                   Change text/metadata model (Paperless-AI + Paperless-GPT)"
  echo "  $0 --vision <model>                 Change vision OCR model (Paperless-GPT only)"
  echo "  $0 --text <model> --vision <model>  Change both"
  echo "  $0 --list                           List currently pulled Ollama models"
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --text)    TEXT_MODEL="$2";   shift 2 ;;
    --vision)  VISION_MODEL="$2"; shift 2 ;;
    --list)    DO_LIST=true;      shift   ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
check_compose_exists() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml not found at $COMPOSE_FILE"
    echo "   Set PAPERLESS_DIR env var if your install is elsewhere."
    exit 1
  fi
}

ollama_exec() {
  if docker compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | grep -q "^paperless-ollama$"; then
    docker compose -f "$COMPOSE_FILE" exec paperless-ollama ollama "$@"
  else
    echo "⚠️  paperless-ollama container is not running — skipping Ollama command."
    return 1
  fi
}

list_models() {
  echo "📦 Pulled Ollama models:"
  ollama_exec list 2>/dev/null || echo "   (could not reach Ollama)"
}

pull_model() {
  local model="$1"
  echo "⬇️  Pulling model: $model (this may take a while)..."
  ollama_exec pull "$model"
}

current_value() {
  local key="$1"
  grep "$key" "$COMPOSE_FILE" | head -1 | sed 's/.*: *//' | tr -d '"'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if $DO_LIST; then
  check_compose_exists
  list_models
  exit 0
fi

check_compose_exists

echo ""
echo "📄 Target compose file: $COMPOSE_FILE"
echo ""

# Show current values
CURRENT_TEXT=$(current_value "OLLAMA_MODEL")
CURRENT_LLM=$(current_value "LLM_MODEL")
CURRENT_VISION=$(current_value "VISION_LLM_MODEL")

echo "Current models:"
[ -n "$CURRENT_TEXT" ]   && echo "  OLLAMA_MODEL (Paperless-AI) : $CURRENT_TEXT"
[ -n "$CURRENT_LLM" ]    && echo "  LLM_MODEL    (Paperless-GPT): $CURRENT_LLM"
[ -n "$CURRENT_VISION" ] && echo "  VISION_LLM_MODEL            : $CURRENT_VISION"
echo ""

# Apply text model change
if [ -n "$TEXT_MODEL" ]; then
  # Pull model first (non-fatal if Ollama isn't running yet)
  pull_model "$TEXT_MODEL" || true

  echo "🔄 Updating OLLAMA_MODEL → $TEXT_MODEL"
  sed -i "s|OLLAMA_MODEL:.*|OLLAMA_MODEL: $TEXT_MODEL|g" "$COMPOSE_FILE"

  echo "🔄 Updating LLM_MODEL → $TEXT_MODEL"
  sed -i "s|LLM_MODEL:.*|LLM_MODEL: $TEXT_MODEL|g" "$COMPOSE_FILE"
fi

# Apply vision model change
if [ -n "$VISION_MODEL" ]; then
  pull_model "$VISION_MODEL" || true

  echo "🔄 Updating VISION_LLM_MODEL → $VISION_MODEL"
  sed -i "s|VISION_LLM_MODEL:.*|VISION_LLM_MODEL: $VISION_MODEL|g" "$COMPOSE_FILE"
fi

# Restart AI services to apply changes
echo ""
echo "♻️  Restarting AI services..."
cd "$APP_DIR"
docker compose restart paperless-ai paperless-gpt

echo ""
echo "✅ Done! New model configuration:"
[ -n "$TEXT_MODEL" ]   && echo "  Text model    : $TEXT_MODEL  (Paperless-AI + Paperless-GPT)"
[ -n "$VISION_MODEL" ] && echo "  Vision model  : $VISION_MODEL  (Paperless-GPT OCR)"
echo ""
echo "   Verify with:"
echo "   docker compose -f $COMPOSE_FILE logs --tail=20 paperless-ai paperless-gpt"
