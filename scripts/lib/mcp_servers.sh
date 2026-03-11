#!/usr/bin/env bash

mcp_servers::normalize_name() {
  echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
  return 0
}

mcp_servers::canonical_name() {
  local normalized
  normalized="$(mcp_servers::normalize_name "$1")"

  case "$normalized" in
    postman|postman-api-mcp)
      echo "postman-api-mcp"
      ;;
    *)
      echo "$normalized"
      ;;
  esac
  return 0
}

mcp_servers::aliases_for_name() {
  local canonical
  canonical="$(mcp_servers::canonical_name "$1")"

  case "$canonical" in
    postman-api-mcp)
      printf "%s\n" "postman" "postman-api-mcp"
      ;;
    *)
      printf "%s\n" "$canonical"
      ;;
  esac
  return 0
}

mcp_servers::resolve_csv() {
  local csv="$1"
  local IFS=','
  local raw=""
  local canonical=""
  local resolved=""
  local -a raw_parts=()

  read -r -a raw_parts <<< "$csv"
  for raw in "${raw_parts[@]-}"; do
    canonical="$(mcp_servers::canonical_name "$raw")"
    [[ -z "$canonical" ]] && continue
    if [[ ",$resolved," != *",$canonical,"* ]]; then
      resolved="${resolved:+$resolved,}$canonical"
    fi
  done

  echo "$resolved"
  return 0
}

mcp_servers::escape_regex() {
  printf '%s' "${1:-}" | sed -e 's/[][(){}.^$?*+|\/\\]/\\&/g'
  return 0
}


mcp_servers::line_matches_name() {
  local line="$1"
  local alias=""
  local alias_re=""

  while IFS= read -r alias; do
    [[ -z "$alias" ]] && continue
    alias_re="$(mcp_servers::escape_regex "$alias")"
    if echo "$line" | grep -Eqi "(^|[[:space:]])${alias_re}([[:space:]]|\\(|:)" ; then
      return 0
    fi
  done <<EOF
$(mcp_servers::aliases_for_name "$2")
EOF

  return 1
}

mcp_servers::matching_lines() {
  local file="$1"
  local server_name="$2"
  local line=""

  while IFS= read -r line; do
    if mcp_servers::line_matches_name "$line" "$server_name"; then
      printf "%s\n" "$line"
    fi
  done < "$file"
}
