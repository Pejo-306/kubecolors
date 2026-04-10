#!/usr/bin/env bash
set -euo pipefail

KUBECOLORS_ENDPOINT=""
FAIL=0
KEY="_smoke_test_$$"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) KUBECOLORS_ENDPOINT="$2"; shift 2 ;;
    *) echo "Usage: $0 --endpoint <host:port>"; exit 1 ;;
  esac
done

if [[ -z "$KUBECOLORS_ENDPOINT" ]]; then
  echo "Usage: $0 --endpoint <host:port>"
  exit 1
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=kubecolors-base-url.sh
source "${_SCRIPT_DIR}/kubecolors-base-url.sh"
KUBECOLORS_BASE_URL="$(kubecolors_normalized_base_url "$KUBECOLORS_ENDPOINT")"

assert() {
  local method="$1" path="$2" expected="$3" label="$4"
  shift 4
  local url="${KUBECOLORS_BASE_URL}${path}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$@" -X "$method" "$url") || code="curl_err"
  if [[ "$code" == "$expected" ]]; then
    echo "PASS  $method $path ($label) — $code"
    return 0
  fi

  echo "FAIL  $method $path ($label) — expected $expected, got $code" >&2
  {
    echo ""
    echo "--- DEBUG (smoke-test assert failure) ---"
    echo "endpoint:    ${KUBECOLORS_ENDPOINT}"
    echo "url:           ${url}"
    echo "method:        ${method}"
    echo "label:         ${label}"
    echo "expected code: ${expected}"
    echo "got code:      ${code}"
    echo "curl args:     $*"
    echo "--- response (status + headers + body, truncated) ---"
    curl -sS -D - "$@" -X "$method" "$url" 2>&1 | head -c 8192 || true
    echo ""
    echo "--- end DEBUG ---"
    echo ""
  } >&2
  FAIL=1
}

# Health / readiness probes
assert GET /up                        200 "liveness"
assert GET /health                    200 "health"
assert GET /ready                     200 "readiness"

# Root API
assert GET /api/                      200 "root endpoint"
assert GET "/api/?format=json"        200 "root endpoint json"

# List colors
assert GET /api/color                 200 "list colors"

# GET non-existent color -> 404
assert GET "/api/color/${KEY}"        404 "get missing color"

# DELETE non-existent color -> 404
assert DELETE "/api/color/${KEY}"     404 "delete missing color"

# PUT non-existent color -> 404
assert PUT "/api/color/${KEY}"        404 "update missing color" \
  -H "Content-Type: application/json" -d '{"color":"#aabbcc"}'

# CREATE color -> 201
assert POST "/api/color/${KEY}"       201 "create color" \
  -H "Content-Type: application/json" -d '{"color":"#ff0000"}'

# CREATE duplicate -> 400
assert POST "/api/color/${KEY}"       400 "create duplicate" \
  -H "Content-Type: application/json" -d '{"color":"#ff0000"}'

# CREATE with invalid hex -> 400
assert POST "/api/color/${KEY}_bad"   400 "create invalid hex" \
  -H "Content-Type: application/json" -d '{"color":"nothex"}'

# GET created color -> 200
assert GET "/api/color/${KEY}"        200 "get created color"

# UPDATE color -> 200
assert PUT "/api/color/${KEY}"        200 "update color" \
  -H "Content-Type: application/json" -d '{"color":"#00ff00"}'

# UPDATE with invalid hex -> 400
assert PUT "/api/color/${KEY}"        400 "update invalid hex" \
  -H "Content-Type: application/json" -d '{"color":"zzz"}'

# DELETE color -> 204
assert DELETE "/api/color/${KEY}"     204 "delete color"

# Verify deletion -> 404
assert GET "/api/color/${KEY}"        404 "verify deleted"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "All smoke tests passed."
  exit 0
else
  echo "Some smoke tests FAILED."
  exit 1
fi
