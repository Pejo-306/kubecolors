#!/usr/bin/env bash
# Normalize a kubecolors endpoint for curl: add http:// when no scheme is present;
# strip trailing slashes. Source this file and call kubecolors_normalized_base_url.

kubecolors_normalized_base_url() {
  local base="$1"
  if [[ -z "$base" ]]; then
    echo "kubecolors_normalized_base_url: empty endpoint" >&2
    return 1
  fi
  if [[ ! "$base" =~ ^https?:// ]]; then
    base="http://${base}"
  fi
  while [[ "$base" == */ ]]; do
    base="${base%/}"
  done
  printf '%s\n' "$base"
}
