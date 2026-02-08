#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/lib/mcp_preflight.sh --phase plan|implement|review|qa --servers "a,b,c" [--output /path/preflight.json]
EOF
}

normalize_bool() {
  local raw
  raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    1|true|yes|on|always) echo "true" ;;
    *) echo "false" ;;
  esac
  return 0
}

json_escape() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/}"
  text="${text//$'\t'/\\t}"
  printf "%s" "$text"
  return 0
}

csv_to_json_array() {
  local csv="$1"
  local IFS=','
  local first=true
  local raw=""
  local -a __csv_parts=()

  read -r -a __csv_parts <<< "$csv"
  printf "["
  for raw in "${__csv_parts[@]-}"; do
    local item
    item="$(echo "$raw" | tr -d '[:space:]')"
    if [[ -z "$item" ]]; then
      continue
    fi
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ","
    fi
    printf "\"%s\"" "$(json_escape "$item")"
  done
  printf "]"
  return 0
}

strip_ansi() {
  sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g' | tr -d '\r'
  return 0
}

csv_to_array() {
  local csv="$1"
  local IFS=','
  read -r -a __raw_parts <<< "$csv"
  __csv_norm_parts=()
  local raw=""
  for raw in "${__raw_parts[@]-}"; do
    local item
    item="$(echo "$raw" | tr -d '[:space:]')"
    if [[ -n "$item" ]]; then
      __csv_norm_parts+=("$item")
    fi
  done
  return 0
}

array_to_json() {
  local first=true
  local value=""
  printf "["
  for value in "$@"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ","
    fi
    printf "\"%s\"" "$(json_escape "$value")"
  done
  printf "]"
  return 0
}

PHASE=""
SERVERS=""
OUTPUT_FILE=""
PREFLIGHT_RETRIES="${AGENT_MCP_PREFLIGHT_RETRIES:-3}"
PREFLIGHT_DELAY_SECONDS="${AGENT_MCP_PREFLIGHT_DELAY_SECONDS:-2}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="$2"
      shift 2
      ;;
    --servers)
      SERVERS="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PHASE" ]]; then
  echo "Missing --phase." >&2
  exit 2
fi

if ! [[ "$PREFLIGHT_RETRIES" =~ ^[0-9]+$ ]] || [[ "$PREFLIGHT_RETRIES" -lt 1 ]]; then
  PREFLIGHT_RETRIES=3
fi
if ! [[ "$PREFLIGHT_DELAY_SECONDS" =~ ^[0-9]+$ ]] || [[ "$PREFLIGHT_DELAY_SECONDS" -lt 1 ]]; then
  PREFLIGHT_DELAY_SECONDS=2
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$(pwd)/tmp/state/preflight_${PHASE}.json"
fi
mkdir -p "$(dirname "$OUTPUT_FILE")"

REQUESTED_JSON="$(csv_to_json_array "$SERVERS")"
EMPTY_JSON_ARRAY="[]"

CHECKED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
STATUS="skipped"
CMD_EXIT=0
SNIPPET=""
CONNECTED_JSON="$EMPTY_JSON_ARRAY"
DISCONNECTED_JSON="$EMPTY_JSON_ARRAY"
MISSING_JSON="$EMPTY_JSON_ARRAY"

if [[ "$(normalize_bool "${AGENT_MCP_PREFLIGHT:-true}")" != "true" ]]; then
  cat > "$OUTPUT_FILE" <<EOF
{
  "phase": "$(json_escape "$PHASE")",
  "checked_at": "$(json_escape "$CHECKED_AT")",
  "status": "skipped",
  "requested_servers": $REQUESTED_JSON,
  "connected_servers": $EMPTY_JSON_ARRAY,
  "disconnected_servers": $EMPTY_JSON_ARRAY,
  "missing_servers": $EMPTY_JSON_ARRAY,
  "gemini_exit_code": 0,
  "output_snippet": ""
}
EOF
  exit 0
fi

if [[ -z "$(echo "$SERVERS" | tr -d '[:space:]')" ]]; then
  cat > "$OUTPUT_FILE" <<EOF
{
  "phase": "$(json_escape "$PHASE")",
  "checked_at": "$(json_escape "$CHECKED_AT")",
  "status": "ok",
  "requested_servers": $EMPTY_JSON_ARRAY,
  "connected_servers": $EMPTY_JSON_ARRAY,
  "disconnected_servers": $EMPTY_JSON_ARRAY,
  "missing_servers": $EMPTY_JSON_ARRAY,
  "gemini_exit_code": 0,
  "output_snippet": ""
}
EOF
  exit 0
fi

if ! command -v gemini >/dev/null 2>&1; then
  STATUS="failed"
  CMD_EXIT=127
  SNIPPET="gemini CLI is not installed or not available in PATH."
else
  TMP_OUTPUT="$(mktemp)"
  CLEAN_OUTPUT="$(mktemp)"
  csv_to_array "$SERVERS"
  requested_arr=("${__csv_norm_parts[@]}")

  attempt=1
  while [[ "$attempt" -le "$PREFLIGHT_RETRIES" ]]; do
    set +e
    gemini mcp list > "$TMP_OUTPUT" 2>&1
    CMD_EXIT=$?
    set -e

    strip_ansi < "$TMP_OUTPUT" > "$CLEAN_OUTPUT"
    SNIPPET="$(tail -n 80 "$CLEAN_OUTPUT" | sed 's/[[:cntrl:]]//g')"

    connected_arr=()
    disconnected_arr=()
    missing_arr=()

    for server in "${requested_arr[@]}"; do
      # Match either "<server>:" or "<server> (from ...):" lines from "gemini mcp list".
      lines="$(grep -Ei "[[:space:]]$server([[:space:]]|\\(|:)" "$CLEAN_OUTPUT" || true)"
      if [[ -z "$lines" ]]; then
        missing_arr+=("$server")
        continue
      fi

      # Prefer healthy statuses if any line indicates Ready/Connected.
      if echo "$lines" | grep -Eqi -- "-[[:space:]]*(Connected|Ready)"; then
        connected_arr+=("$server")
      else
        disconnected_arr+=("$server")
      fi
    done

    if [[ ${#missing_arr[@]} -eq 0 ]] && [[ ${#disconnected_arr[@]} -eq 0 ]]; then
      STATUS="ok"
      break
    fi

    STATUS="failed"
    if [[ "$attempt" -lt "$PREFLIGHT_RETRIES" ]]; then
      sleep "$PREFLIGHT_DELAY_SECONDS"
    fi
    attempt=$((attempt + 1))
  done

  set +u
  CONNECTED_JSON="$(array_to_json "${connected_arr[@]}")"
  DISCONNECTED_JSON="$(array_to_json "${disconnected_arr[@]}")"
  MISSING_JSON="$(array_to_json "${missing_arr[@]}")"
  set -u

  rm -f "$TMP_OUTPUT" "$CLEAN_OUTPUT"
fi

cat > "$OUTPUT_FILE" <<EOF
{
  "phase": "$(json_escape "$PHASE")",
  "checked_at": "$(json_escape "$CHECKED_AT")",
  "status": "$(json_escape "$STATUS")",
  "requested_servers": $REQUESTED_JSON,
  "connected_servers": $CONNECTED_JSON,
  "disconnected_servers": $DISCONNECTED_JSON,
  "missing_servers": $MISSING_JSON,
  "gemini_exit_code": $CMD_EXIT,
  "output_snippet": "$(json_escape "$SNIPPET")"
}
EOF

if [[ "$STATUS" != "ok" ]]; then
  echo "MCP preflight failed for phase '$PHASE'." >&2
  echo "Requested MCP servers: $SERVERS" >&2
  if [[ "$DISCONNECTED_JSON" != "[]" ]]; then
    echo "Disconnected servers: $DISCONNECTED_JSON" >&2
  fi
  if [[ "$MISSING_JSON" != "[]" ]]; then
    echo "Missing servers: $MISSING_JSON" >&2
  fi
  echo "Details: $OUTPUT_FILE" >&2
  if [[ -n "$SNIPPET" ]]; then
    echo "Snippet (tail): $SNIPPET" >&2
  fi
  exit 1
fi

exit 0
