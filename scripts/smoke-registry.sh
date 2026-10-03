#!/usr/bin/env bash
# Prueba de humo del registry: pull → tag → push a localhost:5001 → deploy desde el clúster.
source "$(dirname "$0")/lib.sh"
CLUSTER="${1:-plataforma}"; CTX="kind-$CLUSTER"
SRC="nginxinc/nginx-unprivileged:1.27-alpine"
DST="localhost:$REGISTRY_PORT/lab/nginx-unprivileged:1.27-alpine"

step "Publicando $SRC como $DST"
docker pull -q "$SRC" >/dev/null
docker tag "$SRC" "$DST"
docker push -q "$DST" >/dev/null
ok "publicada"

step "Desplegando desde el registry local"
kubectl --context "$CTX" apply -f "$ROOT/workloads/smoke/registry-smoke.yaml" >/dev/null
kubectl --context "$CTX" -n smoke rollout status deploy/registry-smoke --timeout=120s
ok "el clúster descargó la imagen desde el registry local"
