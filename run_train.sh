#!/usr/bin/env bash
set -uo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
LOG_FILE="${LOG_FILE:-run.log}"

unload_all_ollama_models() {
  local models

  models="$(
    curl -sS "${OLLAMA_HOST}/api/ps" 2>/dev/null \
      | jq -r '.models[]?.name' 2>/dev/null
  )" || return 0

  while IFS= read -r model; do
    [ -z "$model" ] && continue

    curl -sS "${OLLAMA_HOST}/api/generate" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"${model}\",\"keep_alive\":0}" \
      >/dev/null 2>&1 || true
  done <<< "$models"
}

reload_recent_ollama_model() {
  local model="$1"

  [ -z "$model" ] && return 0

  curl -sS "${OLLAMA_HOST}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\"}" \
    >/dev/null 2>&1 || true
}

RELOAD_MODEL="$(
  curl -sS "${OLLAMA_HOST}/api/ps" 2>/dev/null \
    | jq -r '.models[0]?.name // empty' 2>/dev/null
)" || RELOAD_MODEL=""

unload_all_ollama_models

sleep 3

uv run train.py > "${LOG_FILE}" 2>&1
TRAIN_EXIT_CODE=$?

reload_recent_ollama_model "${RELOAD_MODEL}"

if [ "${TRAIN_EXIT_CODE}" -eq 0 ]; then
  echo "Train run complete."
else
  echo "Train run failed. Check ${LOG_FILE}."
fi

exit "${TRAIN_EXIT_CODE}"
