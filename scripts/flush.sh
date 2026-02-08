#!/usr/bin/env bash
set -euo pipefail

KUBECOLORS_ENDPOINT=""
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) KUBECOLORS_ENDPOINT="$2"; shift 2 ;;
    -y)         AUTO_YES=true; shift ;;
    *) echo "Usage: $0 --endpoint <host:port> [-y]"; exit 1 ;;
  esac
done

if [[ -z "$KUBECOLORS_ENDPOINT" ]]; then
  echo "Usage: $0 --endpoint <host:port> [-y]"
  exit 1
fi

keys=$(curl -s "http://${KUBECOLORS_ENDPOINT}/api/color" | jq -r '.[].key')
total=$(echo "$keys" | grep -c . || true)

if [[ "$total" -eq 0 ]]; then
  echo "No colors to delete."
  exit 0
fi

echo "Found $total color(s) to delete."

if [[ "$AUTO_YES" == false ]]; then
  printf "Are you sure you want to delete all %d colors? [y/N] " "$total"
  read -r answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

ok=0
fail=0

while IFS= read -r key; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://${KUBECOLORS_ENDPOINT}/api/color/${key}")
  if [[ "$code" == "204" ]]; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
    echo "FAIL  DELETE /api/color/${key} — $code"
  fi
  printf "\r%d/%d deleted (%d failed)" "$ok" "$total" "$fail"
done <<< "$keys"

echo ""
echo "Done. ${ok} deleted, ${fail} failed out of ${total}."
[[ "$fail" -eq 0 ]]
