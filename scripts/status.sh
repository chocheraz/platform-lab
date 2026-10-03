#!/usr/bin/env bash
# Foto rápida del lab: clústeres, nodos, registry y consumo real de memoria.
source "$(dirname "$0")/lib.sh"
step "Clústeres kind"; kind get clusters 2>/dev/null || true
for c in $(kind get clusters 2>/dev/null); do
  step "Nodos de $c"; kubectl --context "kind-$c" get nodes -o wide 2>/dev/null || warn "API de $c no responde (¿pausado?)"
done
step "Registry"; docker ps --filter "name=^${REGISTRY_NAME}$" --format '{{.Names}}  {{.Status}}  {{.Ports}}'
step "Consumo de los contenedores del lab"
ids=(); while IFS= read -r i; do [[ -n "$i" ]] && ids+=("$i"); done < <(docker ps -q --filter label=io.x-k8s.kind.cluster; docker ps -q --filter "name=^${REGISTRY_NAME}$")
if (( ${#ids[@]} > 0 )); then docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' "${ids[@]}"; else warn "nada corriendo"; fi
