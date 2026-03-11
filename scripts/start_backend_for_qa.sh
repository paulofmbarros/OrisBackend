#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_LOG_FILE="$REPO_ROOT/tmp/state/backend_for_qa.log"
BACKEND_PID_FILE="$REPO_ROOT/tmp/state/backend_for_qa.pid"
BACKEND_START_TIMEOUT_SECONDS="${AGENT_BACKEND_QA_STARTUP_TIMEOUT_SECONDS:-120}"

mkdir -p "$(dirname "$BACKEND_LOG_FILE")"

resolve_dotnet_cmd() {
  if [[ -x "/Users/paulofmbarros/.dotnet/dotnet" ]]; then
    echo "/Users/paulofmbarros/.dotnet/dotnet"
  elif command -v dotnet >/dev/null 2>&1; then
    command -v dotnet
  elif [[ -x "/usr/local/share/dotnet/dotnet" ]]; then
    echo "/usr/local/share/dotnet/dotnet"
  else
    return 1
  fi
}

backend_is_healthy() {
  local response_file
  local http_code=""

  response_file="$(mktemp)"
  http_code="$(curl -sS --max-time 5 -o "$response_file" -w "%{http_code}" http://localhost:5134/health 2>/dev/null || true)"
  rm -f "$response_file"
  [[ "$http_code" == "200" ]]
}

DOTNET_CMD="$(resolve_dotnet_cmd)" || {
  echo "dotnet CLI not found." >&2
  exit 1
}

if backend_is_healthy; then
  echo "Backend already healthy on http://localhost:5134"
  exit 0
fi

echo "Starting backend..."
echo "Backend log: $BACKEND_LOG_FILE"
"$DOTNET_CMD" run --project "$REPO_ROOT/src/Oris.Api/Oris.WebApplication/Oris.WebApplication.csproj" --urls "http://localhost:5134" > "$BACKEND_LOG_FILE" 2>&1 &
PID=$!
printf "%s\n" "$PID" > "$BACKEND_PID_FILE"
echo "Backend started with PID $PID"

echo "Waiting for health check..."
backend_ready=false
for ((i = 1; i <= BACKEND_START_TIMEOUT_SECONDS; i++)); do
  if backend_is_healthy; then
    echo "Backend is ready!"
    backend_ready=true
    break
  fi
  sleep 1
done

if [[ "$backend_ready" != "true" ]]; then
  echo "Backend failed to become healthy within ${BACKEND_START_TIMEOUT_SECONDS} seconds." >&2
  if [[ -s "$BACKEND_LOG_FILE" ]]; then
    echo "Backend log tail:" >&2
    tail -n 80 "$BACKEND_LOG_FILE" >&2 || true
  fi
  kill "$PID" >/dev/null 2>&1 || true
  sleep 1
  kill -9 "$PID" >/dev/null 2>&1 || true
  exit 1
fi
