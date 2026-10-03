#!/usr/bin/env bash
# Pausa o reanuda un clúster para liberar RAM entre sesiones.
# Uso: scripts/lifecycle.sh pause|resume [plataforma|satelite]
source "$(dirname "$0")/lib.sh"
action="${1:?pause|resume}"; CLUSTER="${2:-plataforma}"
# Compatible con bash 3.2 (macOS): sin mapfile
nodes=(); while IFS= read -r n; do [[ -n "$n" ]] && nodes+=("$n"); done < <(kind get nodes --name "$CLUSTER" 2>/dev/null)
(( ${#nodes[@]} > 0 )) || die "El clúster $CLUSTER no existe"
case "$action" in
  pause)  docker stop "${nodes[@]}" >/dev/null; ok "$CLUSTER pausado (el estado se conserva)";;
  resume)
    docker start "${nodes[@]}" >/dev/null
    step "Esperando al API server y a los nodos"
    for _ in $(seq 1 60); do kubectl --context "kind-$CLUSTER" get --raw=/readyz >/dev/null 2>&1 && break; sleep 3; done
    kubectl --context "kind-$CLUSTER" wait --for=condition=Ready nodes --all --timeout=180s
    ok "$CLUSTER reanudado";;
  *) die "acción inválida: $action";;
esac
