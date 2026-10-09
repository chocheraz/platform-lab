La version ingenua es peligrosa pq una politica mal escrita permite admitir pods
con huevos de seguridos obvios
Un : en una referencia de imagen puede ser el puerto del registry o el separador del tag. Para distinguirlos hay que mirar solo el último segmento del path.
Un chequeo hecho con grep o contains sobre texto plano acierta en los casos comunes y falla en los bordes. Por eso el módulo insiste en probar las políticas con casos de borde.
Para entrevista: "Las heurísticas con regex sobre el nombre de la imagen son frágiles. Mi política parsea la referencia: aísla el último segmento, contempla digests y revisa todos los tipos de contenedor."


# Notas del Módulo 1 — Admisión y Kyverno

> Plantilla con las conclusiones de cada lab. Donde diga **(tu salida)**, pega lo que obtuviste
> en tu clúster: es tu evidencia, no la mía.

## Lab 1.1 — Instalación y webhooks

**Estado antes de crear políticas** (comando `jq` sobre `validatingwebhookconfigurations`):

```
(tu salida)
```

Seis configuraciones de Kyverno (políticas, excepciones, `cel-exception`, `global-context`,
`cleanup`, `ttl`). Todas validan objetos propios de Kyverno. Ninguna intercepta Pods todavía.
Instalar Kyverno no protege nada hasta cargar políticas.

**Estado después de crear políticas:**

```
(tu salida)
```

Aparece `kyverno-resource-validating-webhook-cfg` con **dos** entradas:

| Entrada | `failurePolicy` | Origen |
|---|---|---|
| `vpol.validate.kyverno.svc-ignore-…` | Ignore | Políticas Audit (`failurePolicy: Ignore`) |
| `vpol.validate.kyverno.svc-fail-…` | Fail | Políticas `-enforce` |

Las dos cubren `pods`, `deployments`, `replicasets`, `daemonsets`, `statefulsets`, `cronjobs`
y `jobs`. La de `Fail` además trae `matchLabels: politicas.curso.lab/modo: enforce`: el selector
de la política **se traslada al webhook**.

**Cómo saber que el motor realmente está activo:** no basta con ver los pods `Running`. Hay que
comprobar que existe el webhook de recursos y qué namespaces cubre.

## Lab 1.2 — Políticas CEL y casos de prueba

**Los dos defectos de la política ingenua** (`kyverno apply labs/m1/ingenua.yaml --resource labs/m1/casos.yaml -t`):

1. **Error cuando falta `securityContext`.** `c.securityContext.privileged` lanza error si el
   campo no existe; CEL no inventa defaults. Resultado `Error`, que con `failurePolicy: Fail`
   rechaza un pod legítimo y con `Ignore` lo deja pasar sin evaluar. Arreglo:
   `c.?securityContext.?privileged.orValue(false)`.
2. **Solo revisa `spec.containers`.** Un `initContainer` privilegiado pasa como `Pass`. Arreglo:
   concatenar `containers + initContainers + ephemeralContainers` con `spec.?initContainers.orValue([])`.

**Tercer caso que agregué (`ephemeralContainer` privilegiado):** el Pod de prueba trae un
`ephemeralContainer` con `privileged: true`. La política ingenua lo da por bueno. En el clúster
real los efímeros entran por el subrecurso `pods/ephemeralcontainers` (lo que usa
`kubectl debug`), que una política sobre `pods` **no cubre**; hay que agregarlo en
`matchConstraints`.

**Por qué "ausente" no significa lo mismo en todos los campos:**

| Campo | Si falta | Consecuencia para la política |
|---|---|---|
| `privileged` | `false` (seguro) | `orValue(false)` |
| `allowPrivilegeEscalation` | `true` (inseguro) | La ausencia debe contar como incumplimiento |
| `runAsNonRoot` | Puede correr como root | La ausencia debe **fallar** |

Pregunta de entrevista: "¿qué hace tu política cuando el campo no existe?"

**Heurística del script del M0 vs la política (`disallow-latest-tag`):**

El script decide que hay tag si la imagen contiene `:`. Con `localhost:5001/app` el `:` es el
**puerto del registry**, no un tag: el script la da por buena y es un falso negativo (esa imagen
resuelve a `latest`). La política busca el tag **después del último `/`**:
`c.image.substring(c.image.lastIndexOf('/') + 1).contains(':')`, y además excluye los digests
(`@sha256:…`), que son inmutables. Conclusión: las heurísticas sobre texto fallan en los bordes;
hay que parsear la referencia.

## Lab 1.3 — Auditoría y reportes

`make policies-check` (CLI, sin clúster): `pass: 14, fail: 10, warn: 0, error: 0`.

| Carga | Fallos |
|---|---|
| `api-pagos` | hostPath, sin límite de memoria, sin `runAsNonRoot`, capability `NET_ADMIN` (4) |
| `batch-reportes` | `:latest`, privilegiado, sin límite de memoria, sin `runAsNonRoot` (4) |
| `portal-tramites` | sin límite de memoria, sin `runAsNonRoot` (2) |
| `portal-moderno` | ninguno |

`make` termina con "Error 1" porque el CLI sale con código distinto de cero cuando hay
incumplimientos; es el comportamiento deseado en CI.

`make reporte` → `docs/reportes/cumplimiento-m1.md`: **(tu salida)**

## Lab 1.4 — Audit → Enforce por namespace

- El enforcement es una decisión **por namespace**, activada con la etiqueta
  `politicas.curso.lab/modo=enforce`. El selector vive en `spec.matchConstraints.namespaceSelector`
  de cada política `-enforce` (lo agrega el patch de `policies/enforce/kustomization.yaml`); el
  sufijo `-enforce` del nombre no participa en el emparejamiento.
- `piloto-ok` (cumple) se despliega en Enforce; `no-cumple` se rechaza en el `apply`.

**PSA vs Kyverno, misma carga `no-cumple`:**

| | PSA `restricted` (`apps-modernas`) | Kyverno enforce (`equipo-piloto`) |
|---|---|---|
| Qué ocurre en el `apply` | Warning; el Deployment **se crea** (`0/1`) | **Rechazo inmediato** |
| Dónde está el error | Eventos del ReplicaSet (`violates PodSecurity`) | En la respuesta del `apply` |
| Efecto en pipelines/GitOps | Parece exitoso, falla después | El pipeline reporta el fallo |
| Personalización | Tres perfiles fijos | Políticas propias, mensajes, excepciones |

**El incidente de `legacy-tramites`:** poner el namespace en Enforce no rompe nada hoy (los pods
existentes siguen `Running`; la admisión no toca lo que ya está en etcd). Rompe el **próximo**
despliegue: `rollout restart` es un UPDATE del Deployment y se rechaza.

**`scale` vs `rollout restart`:** **(tu observación)**. `scale` usa el subrecurso
`deployments/scale`, que las políticas no cubren, así que el escalado se acepta; pero el
ReplicaSet intenta crear un Pod nuevo y **ese Pod** sí coincide con la regla de pods y se
rechaza. Queda en `2/3` con el error en los eventos. Un HPA en un pico de tráfico sufriría lo
mismo: la política te deja sin capacidad cuando más la necesitas.

**Regla de entrada a Enforce:** un namespace pasa a Enforce solo cuando su reporte de
cumplimiento está en cero (o lo que queda tiene excepción aprobada).

## Ejercicio de ruptura 1.R

Ver `docs/runbooks/0002-nadie-puede-desplegar.md`. Hallazgos que quiero recordar:

1. Apagado limpio (escalar a 0) → Kyverno retira sus webhooks → todo pasa sin control (fail-open).
2. Servicio sin endpoints con webhooks registrados → la entrada `Fail` bloquea; la `Ignore`
   deja pasar.
3. El radio de impacto lo define la `ValidatingWebhookConfiguration`, no la política.
4. `rollout status` puede decir "successfully rolled out" cuando el cambio fue rechazado.
5. El namespace `kyverno` excluido hace posible recuperarse (y es un punto ciego asumido).

## Lo que haría distinto en un ministerio con 60 microservicios

1. Todo en Audit primero; medir con los reportes.
2. Corregir con los equipos hasta dejar el reporte en cero por namespace.
3. Enforce por namespace, empezando por los nuevos o los limpios, con etiqueta visible.
4. `Fail` solo para seguridad crítica; el resto `Ignore`.
5. Excepciones con dueño y fecha de caducidad (M2).
6. Alertas sobre la disponibilidad del admission controller y de sus endpoints.