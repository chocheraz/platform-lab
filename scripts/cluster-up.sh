#!/usr/bin/env bash
# Crea (idempotente) el registry local y un clúster kind conectado a él.
# Uso: scripts/cluster-up.sh [plataforma|satelite]
source "$(dirname "$0")/lib.sh"
CLUSTER="${1:-plataforma}"
CFG="$ROOT/platform/kind/$CLUSTER.yaml"
CTX="kind-$CLUSTER"
[[ -f "$CFG" ]] || die "No existe $CFG"

step "1/5 Registry local ($REGISTRY_NAME en 127.0.0.1:$REGISTRY_PORT)"
if [[ "$(docker inspect -f '{{.State.Running}}' "$REGISTRY_NAME" 2>/dev/null || true)" != "true" ]]; then
  docker rm -f "$REGISTRY_NAME" >/dev/null 2>&1 || true
  docker run -d --restart=always -p "127.0.0.1:$REGISTRY_PORT:5000" --network bridge \
    --name "$REGISTRY_NAME" "$REGISTRY_IMAGE" >/dev/null
  ok "creado"
else ok "ya corría"; fi

step "2/5 Clúster $CLUSTER"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then ok "ya existe"
else
  kind create cluster --name "$CLUSTER" --config "$CFG" --image "$KIND_NODE_IMAGE" --wait 180s
  ok "creado"
fi

step "3/5 Alias de registry en containerd de cada nodo"
# 'localhost' dentro de un nodo NO es el localhost del host: se redirige al contenedor del registry.
REG_DIR="/etc/containerd/certs.d/localhost:$REGISTRY_PORT"
for node in $(kind get nodes --name "$CLUSTER"); do
  docker exec "$node" mkdir -p "$REG_DIR"
  printf '[host."http://%s:5000"]\n' "$REGISTRY_NAME" | docker exec -i "$node" cp /dev/stdin "$REG_DIR/hosts.toml"
  ok "$node"
done

step "4/5 Registry en la red 'kind'"
if [[ "$(docker inspect -f '{{json .NetworkSettings.Networks.kind}}' "$REGISTRY_NAME")" == "null" ]]; then
  docker network connect kind "$REGISTRY_NAME"; ok "conectado"
else ok "ya conectado"; fi

step "5/5 ConfigMap estándar local-registry-hosting (KEP-1755)"
kubectl --context "$CTX" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:$REGISTRY_PORT"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
YAML
ok "aplicado"

echo; ok "Listo. Contexto: $CTX"
