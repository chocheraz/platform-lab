# Reporte de cumplimiento — Kyverno

- **Generado:** 2026-10-07 23:00 -05
- **Clúster:** `kind-plataforma`
- **Fuente:** `PolicyReport` (wgpolicyk8s.io/v1alpha2), resultados `fail` de controladores
- **Total:** 10 incumplimientos en 3 cargas

## Por política

| Política | Incumplimientos |
|---|---|
| require-memory-limits | 3 |
| require-run-as-non-root | 3 |
| disallow-host-path | 1 |
| disallow-latest-tag | 1 |
| disallow-privileged | 1 |
| restrict-capabilities | 1 |

## Por namespace

| Namespace | Cargas con hallazgos | Incumplimientos |
|---|---|---|
| legacy-tramites | 2 | 6 |
| legacy-pagos | 1 | 4 |

## Detalle

| Namespace | Carga | Política | Mensaje |
|---|---|---|---|
| legacy-pagos | Deployment/api-pagos | disallow-host-path | Volúmenes hostPath no permitidos: logs-nodo -> /var/log |
| legacy-pagos | Deployment/api-pagos | require-memory-limits | Sin resources.limits.memory: api |
| legacy-pagos | Deployment/api-pagos | require-run-as-non-root | Sin runAsNonRoot: true (en el pod o en el contenedor): api |
| legacy-pagos | Deployment/api-pagos | restrict-capabilities | Capabilities no permitidas: NET_ADMIN |
| legacy-tramites | Deployment/batch-reportes | disallow-latest-tag | Imagen sin tag o con :latest: batch (busybox:latest) |
| legacy-tramites | Deployment/batch-reportes | disallow-privileged | Contenedores privilegiados no permitidos: batch |
| legacy-tramites | Deployment/batch-reportes | require-memory-limits | Sin resources.limits.memory: batch |
| legacy-tramites | Deployment/batch-reportes | require-run-as-non-root | Sin runAsNonRoot: true (en el pod o en el contenedor): batch |
| legacy-tramites | Deployment/portal-tramites | require-memory-limits | Sin resources.limits.memory: web |
| legacy-tramites | Deployment/portal-tramites | require-run-as-non-root | Sin runAsNonRoot: true (en el pod o en el contenedor): web |
