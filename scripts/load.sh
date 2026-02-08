#!/usr/bin/env bash
set -euo pipefail

KUBECOLORS_ENDPOINT=""
RECORDS=200
KEY_LENGTH=6

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)    KUBECOLORS_ENDPOINT="$2"; shift 2 ;;
    --records|-n)  RECORDS="$2";  shift 2 ;;
    --key-length|-l) KEY_LENGTH="$2"; shift 2 ;;
    *) echo "Usage: $0 --endpoint <host:port> [-n <records>] [-l <key-length>]"; exit 1 ;;
  esac
done

if [[ -z "$KUBECOLORS_ENDPOINT" ]]; then
  echo "Usage: $0 --endpoint <host:port> [-n <records>] [-l <key-length>]"
  exit 1
fi

rand_key() { cat /dev/urandom | LC_ALL=C tr -dc 'a-z' | head -c "$KEY_LENGTH" || true; }
rand_hex() { printf '#%06x' $((RANDOM * RANDOM % 16777216)); }

ok=0
fail=0

for i in $(seq 1 "$RECORDS"); do
  key=$(rand_key)
  hex=$(rand_hex)
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "http://${KUBECOLORS_ENDPOINT}/api/color/${key}" \
    -H "Content-Type: application/json" \
    -d "{\"color\":\"${hex}\"}")
  if [[ "$code" == "201" ]]; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    echo "FAIL  POST /api/color/${key} (${hex}) — $code"
  fi
  printf "\r%d/%d loaded (%d failed)" "$ok" "$RECORDS" "$fail"
done

echo ""
echo "Done. ${ok} created, ${fail} failed out of ${RECORDS}."
[[ "$fail" -eq 0 ]]
