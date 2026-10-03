#!/usr/bin/env bash
# Uso: scripts/cluster-down.sh [plataforma|satelite|todo]
source "$(dirname "$0")/lib.sh"
target="${1:-plataforma}"
if [[ "$target" == "todo" ]]; then
  for c in $(kind get clusters 2>/dev/null); do kind delete cluster --name "$c"; done
  if docker rm -f "$REGISTRY_NAME" >/dev/null 2>&1; then ok "registry eliminado"; fi
else
  kind delete cluster --name "$target"
fi
