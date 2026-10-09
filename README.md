# platform-lab

Plataforma interna de referencia construida sobre Kubernetes local (kind), módulo a módulo:
admisión gobernada por políticas, observabilidad correlacionada de métricas, logs y trazas,
GitOps y un portal de desarrolladores.

Este repositorio es, a la vez, material de estudio y evidencia pública. Cada módulo cierra con
un tag (`m0-done`, `m1-done`, …) y su entrada en [`docs/cv-evidence.md`](docs/cv-evidence.md).

## Levantarlo

Requisitos: Docker (o Docker Desktop / WSL2) con al menos 8 GiB asignados (16 GiB para el
curso completo), cgroup v2, `make`, `curl`, `bash`.

```bash
make tools     # kind, kubectl, helm y kyverno CLI fijados en ./.bin, con checksum
make doctor    # chequeo previo de la máquina
make up        # registry local + clúster "plataforma" (1 control plane + 2 workers)
make seed      # cargas de partida: legado deliberadamente inseguro + una app moderna
make status    # qué está corriendo y cuánta memoria usa
```

Entre sesiones: `make pause` / `make resume`. Si algo se enreda: `make reset` lo reconstruye
desde cero en pocos minutos. 

## Estado

| Módulo | Tema | Estado |
|---|---|---|
| M0 | Entorno y punto de partida | en curso — tiempo de `make reset reconstruye el punto de partida desde cero en ~56 s (con imágenes en caché)" - Completado |
| M1 | Admisión y Kyverno: fundamentos | en curso |
| M2 | Kyverno avanzado | — |
| M3 | Kyverno como código | — |
| M4 | ADR: Kyverno vs Gatekeeper vs nativo | — |
| M5 | OpenTelemetry | — |
| M6 | Tempo | — |
| M7 | Loki | — |
| M8 | Thanos | — |
| M9 | Correlación + SLO | — |
| M10 | FluxCD vs ArgoCD | — |
| M11 | Backstage | — |
| M12 | Capstone | — |

## Versiones

Todas en [`versions.env`](versions.env). Nada se instala con `latest`.

## Decisiones

En [`docs/adr/`](docs/adr/).
