#!/usr/bin/env bash
# Genera un reporte de cumplimiento en Markdown a partir de los PolicyReport de Kyverno.
# Uso: scripts/reporte-cumplimiento.sh [plataforma] > docs/reportes/cumplimiento-m1.md
#
# Cuenta solo los CONTROLADORES (Deployment, StatefulSet, DaemonSet, CronJob):
# la misma violación aparece también en el reporte de cada Pod que crean, y contarla
# en ambos inflaría las cifras. Los pods sueltos (sin controlador) se listan aparte.
source "$(dirname "$0")/lib.sh"
CTX="kind-${1:-plataforma}"
command -v jq >/dev/null || die "Falta jq"

json="$(kubectl --context "$CTX" get policyreports.wgpolicyk8s.io -A -o json)"

fallas() { # $1 = filtro jq sobre .scope
  jq -c "[.items[] | .scope as \$s | select($1)
          | .results[]? | select(.result == \"fail\")
          | {ns: \$s.namespace, kind: \$s.kind, name: \$s.name, policy, message}]" <<<"$json"
}
ctrl="$(fallas '.scope.kind | IN("Deployment","StatefulSet","DaemonSet","CronJob")')"
pods="$(jq -c '[.items[] | select(.scope.kind == "Pod" and ((.scope.name // "") != ""))
                | select(.metadata.ownerReferences == null) ]' <<<"$json")"

total=$(jq 'length' <<<"$ctrl")
recursos=$(jq '[.[] | "\(.ns)/\(.kind)/\(.name)"] | unique | length' <<<"$ctrl")

cat <<MD
# Reporte de cumplimiento — Kyverno

- **Generado:** $(date '+%Y-%m-%d %H:%M %Z')
- **Clúster:** \`$CTX\`
- **Fuente:** \`PolicyReport\` (wgpolicyk8s.io/v1alpha2), resultados \`fail\` de controladores
- **Total:** $total incumplimientos en $recursos cargas

## Por política

| Política | Incumplimientos |
|---|---|
$(jq -r 'group_by(.policy) | map({p: .[0].policy, n: length}) | sort_by(-.n)[] | "| \(.p) | \(.n) |"' <<<"$ctrl")

## Por namespace

| Namespace | Cargas con hallazgos | Incumplimientos |
|---|---|---|
$(jq -r 'group_by(.ns) | map({ns: .[0].ns, c: ([.[] | .name] | unique | length), n: length}) | sort_by(-.n)[] | "| \(.ns) | \(.c) | \(.n) |"' <<<"$ctrl")

## Detalle

| Namespace | Carga | Política | Mensaje |
|---|---|---|---|
$(jq -r 'sort_by(.ns, .name, .policy)[] | "| \(.ns) | \(.kind)/\(.name) | \(.policy) | \(.message | gsub("\\|"; "\\\\|")) |"' <<<"$ctrl")
MD

if [[ "$(jq 'length' <<<"$pods")" != "0" ]]; then
  echo; echo "> Hay pods sin controlador con reportes propios; revísalos con \`kubectl get polr -A\`."
fi
