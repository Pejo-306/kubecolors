#!/usr/bin/env bash
set -euo pipefail

ENDPOINT=""
CONCURRENT=10
RECORDS=100
UPDATES=50
GETS=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)            ENDPOINT="$2"; shift 2 ;;
    --concurrent-requests) CONCURRENT="$2"; shift 2 ;;
    --records|-n)          RECORDS="$2"; shift 2 ;;
    --updates|-u)          UPDATES="$2"; shift 2 ;;
    --gets)                GETS="$2"; shift 2 ;;
    *) echo "Usage: $0 --endpoint <host:port> [--concurrent-requests N] [-n N] [-u N] [--gets N]"; exit 1 ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  echo "Usage: $0 --endpoint <host:port> [--concurrent-requests N] [-n N] [-u N] [--gets N]"
  exit 1
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=kubecolors-base-url.sh
source "${_SCRIPT_DIR}/kubecolors-base-url.sh"
BASE="$(kubecolors_normalized_base_url "$ENDPOINT")"
FAILED=""

rand_hex() { printf '#%06x' $((RANDOM * RANDOM % 16777216)); }

# Pre-generate unique test keys and colors
KEYS=()
HEXES=()
for ((i=0; i<RECORDS; i++)); do
  KEYS+=("_lt_${i}_${RANDOM}")
  HEXES+=("$(rand_hex)")
done

# Safety-net cleanup for interrupted runs
cleanup() {
  [[ ${#KEYS[@]} -eq 0 ]] && return
  echo ""
  echo "Waiting 30s before cleanup..."
  sleep 30
  echo "Cleaning up ${#KEYS[@]} test records..."
  local n=0
  for key in "${KEYS[@]}"; do
    curl -s -o /dev/null -X DELETE "${BASE}/api/color/${key}" || true
    n=$((n + 1))
    printf "\r  %d/%d" "$n" "${#KEYS[@]}"
  done
  echo " done."
}
trap cleanup EXIT INT TERM

# Generic concurrent phase runner
run_phase() {
  local label="$1" total="$2" fn="$3"
  local ok=0 fail=0
  local start
  start=$(date +%s)

  for ((i=0; i<total; i+=CONCURRENT)); do
    local pids=()
    local end=$((i + CONCURRENT))
    [[ $end -gt $total ]] && end=$total

    for ((j=i; j<end; j++)); do
      $fn "$j" &
      pids+=($!)
    done

    for pid in "${pids[@]}"; do
      if wait "$pid" 2>/dev/null; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
      fi
    done
    printf "\r  %d/%d (%d failed)" $((ok + fail)) "$total" "$fail"
  done

  local elapsed=$(( $(date +%s) - start ))
  printf "\r  %d/%d (%d failed) — %ds\n" "$total" "$total" "$fail" "$elapsed"

  if [[ $fail -gt 0 ]]; then FAILED="$label"; fi
}

# Phase functions (each invocation runs in a subshell via &)
do_create() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE}/api/color/${KEYS[$1]}" \
    -H "Content-Type: application/json" -d "{\"color\":\"${HEXES[$1]}\"}")
  [[ "$code" == "201" ]]
}

do_get() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE}/api/color/${KEYS[$(($1 % RECORDS))]}")
  [[ "$code" == "200" ]]
}

do_update() {
  local hex
  hex=$(rand_hex)
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "${BASE}/api/color/${KEYS[$(($1 % RECORDS))]}" \
    -H "Content-Type: application/json" -d "{\"color\":\"${hex}\"}")
  [[ "$code" == "200" ]]
}

do_delete() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "${BASE}/api/color/${KEYS[$1]}")
  [[ "$code" == "204" ]]
}

# Health check
code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/up" 2>/dev/null || echo "000")
if [[ "$code" != "200" ]]; then
  echo "Endpoint ${ENDPOINT} is not reachable (HTTP ${code})"
  KEYS=()
  exit 1
fi

echo "Load test: ${RECORDS} creates, ${GETS} gets, ${UPDATES} updates (concurrency: ${CONCURRENT})"
echo ""

t0=$(date +%s)

echo "Phase 1/4 — CREATE ${RECORDS} records"
run_phase "CREATE" "$RECORDS" do_create
echo ""

if [[ -z "$FAILED" ]]; then
  echo "Phase 2/4 — GET ${GETS} requests"
  run_phase "GET" "$GETS" do_get
  echo ""
fi

if [[ -z "$FAILED" ]]; then
  echo "Phase 3/4 — UPDATE ${UPDATES} requests"
  run_phase "UPDATE" "$UPDATES" do_update
  echo ""
fi

echo "Phase 4/4 — DELETE ${RECORDS} records"
run_phase "DELETE" "$RECORDS" do_delete
# Only disable cleanup trap if all deletes succeeded
[[ "$FAILED" != "DELETE" ]] && KEYS=()
echo ""

total_elapsed=$(( $(date +%s) - t0 ))

if [[ -n "$FAILED" ]]; then
  echo "FAILED during: ${FAILED} (${total_elapsed}s total)"
  exit 1
else
  echo "All phases passed. (${total_elapsed}s total)"
  exit 0
fi
