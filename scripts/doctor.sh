#!/usr/bin/env bash
# Chequeo previo: ¿esta máquina puede correr el lab? No modifica nada.
source "$(dirname "$0")/lib.sh"
errors=0

step "Motor de contenedores"
if docker info >/dev/null 2>&1; then ok "Docker responde"; else fail "Docker no responde (¿está iniciado?)"; errors=$((errors+1)); fi

step "Memoria asignada al motor de contenedores"
mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
mem_gb=$(( mem_bytes / 1024 / 1024 / 1024 ))
if   (( mem_gb >= 16 )); then ok "${mem_gb} GiB — alcanza para todo el curso"
elif (( mem_gb >= 12 )); then warn "${mem_gb} GiB — alcanza; en M8 (dos clústeres) apaga lo que no uses"
elif (( mem_gb >= 8  )); then warn "${mem_gb} GiB — justo para M0–M4; desde M5 usarás el perfil ligero"
else fail "${mem_gb} GiB — insuficiente (mínimo 8 GiB para el motor)"; errors=$((errors+1)); fi
cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo 0)"
if (( cpus >= 4 )); then ok "${cpus} CPU"; else warn "${cpus} CPU — mínimo recomendado 4"; fi

step "cgroups"
cg="$(docker info --format '{{.CgroupVersion}}' 2>/dev/null || echo '?')"
if [[ "$cg" == "2" ]]; then ok "cgroup v2"; else fail "cgroup v$cg — Kubernetes 1.35+ retiró el soporte de cgroup v1"; errors=$((errors+1)); fi

if [[ "$(uname -s)" == "Linux" ]]; then
  step "Límites de inotify (varios clústeres kind los agotan)"
  w=$(cat /proc/sys/fs/inotify/max_user_watches); i=$(cat /proc/sys/fs/inotify/max_user_instances)
  if (( w >= 524288 )); then ok "max_user_watches=$w"; else warn "max_user_watches=$w → sube a 524288 (troubleshooting 0.2)"; fi
  if (( i >= 512 ));    then ok "max_user_instances=$i"; else warn "max_user_instances=$i → sube a 512 (troubleshooting 0.2)"; fi
fi

step "Puertos del host que usa el lab"
for p in "$REGISTRY_PORT" 8080 8443; do
  if (echo >"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
    if [[ "$p" == "$REGISTRY_PORT" ]] && docker ps --format '{{.Names}}' | grep -qx "$REGISTRY_NAME"; then ok "$p ocupado por $REGISTRY_NAME (esperado)"
    elif [[ "$p" != "$REGISTRY_PORT" ]] && docker ps --format '{{.Names}}' | grep -qx "plataforma-control-plane"; then ok "$p ocupado por plataforma (esperado)"
    else fail "$p ocupado por otro proceso"; errors=$((errors+1)); fi
  else ok "$p libre"; fi
done

step "Utilidades del sistema"
for t in make curl jq git; do
  if command -v "$t" >/dev/null; then ok "$t"; else fail "$t no está instalado"; errors=$((errors+1)); fi
done

step "Herramientas fijadas"
if kind version 2>/dev/null | grep -q "$KIND_VERSION"; then ok "kind $KIND_VERSION"; else fail "kind $KIND_VERSION ausente → make tools"; errors=$((errors+1)); fi
if kubectl version --client 2>/dev/null | grep -q "$KUBECTL_VERSION"; then ok "kubectl $KUBECTL_VERSION"; else fail "kubectl $KUBECTL_VERSION ausente → make tools"; errors=$((errors+1)); fi
if helm version --short 2>/dev/null | grep -q "$HELM_VERSION"; then ok "helm $HELM_VERSION"; else fail "helm $HELM_VERSION ausente → make tools"; errors=$((errors+1)); fi

echo
if (( errors == 0 )); then ok "Todo en orden"; else die "$errors problema(s) por resolver"; fi
