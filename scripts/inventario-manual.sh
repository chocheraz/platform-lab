#!/usr/bin/env bash
# Inventario "a mano" de malas prácticas en Deployments. Lab 0.3.
# Es una foto: no impide nada, no se entera de lo que llegue mañana. Por eso existe el Módulo 1.
source "$(dirname "$0")/lib.sh"
CTX="kind-${1:-plataforma}"
command -v jq >/dev/null || die "Falta jq"
kubectl --context "$CTX" get deploy -A -o json | jq -r '
.items[] | . as $d | .spec.template.spec as $p | $p.containers[] |
[ $d.metadata.namespace, $d.metadata.name, .name,
  (if .securityContext.privileged == true then "PRIVILEGED" else empty end),
  (if (.image | test(":latest$") or (contains(":") | not)) then "TAG_LATEST" else empty end),
  (if .resources.limits == null then "SIN_LIMITS" else empty end),
  (if ((.securityContext.runAsNonRoot // $p.securityContext.runAsNonRoot) != true) then "PUEDE_SER_ROOT" else empty end),
  (if (.securityContext.capabilities.add // []) | length > 0 then "CAPS_EXTRA" else empty end),
  (if any($p.volumes[]?; .hostPath) then "HOSTPATH" else empty end)
] | select(length > 3) | join("  ")' | sort | column -t
