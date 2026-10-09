# Runbook: Un equipo no puede desplegar y el error menciona un webhook de Kyverno

- **Módulo / ejercicio:** M1-R
- **Tiempo hasta diagnóstico:** 10 min  <!-- complétalo con tu tiempo real -->

## Síntoma

El equipo de `equipo-piloto` reporta que su despliegue falla "sin haber cambiado nada". Otros
equipos despliegan con normalidad. Lo que se ve:

```
$ kubectl -n equipo-piloto rollout restart deploy/piloto-ok
error: failed to patch: Internal error occurred: failed calling webhook
"vpol.validate.kyverno.svc-fail-…": failed to call webhook: Post
"https://kyverno-svc.kyverno.svc:443/vpol/…?timeout=10s": dial tcp 10.x.x.x:443: connect: connection refused
```

Dos detalles que despistan:

- `kubectl rollout status deploy/piloto-ok` responde **"successfully rolled out"**. Es falso en
  el sentido útil: describe el despliegue **anterior**, que nunca cambió, porque el cambio fue
  rechazado.
- No hay ReplicaSet nuevo ni evento `FailedCreate`: el rechazo ocurre sobre el **Deployment**,
  antes de que exista un Pod.

## Hipótesis que consideré (en orden)

1. **El Deployment o su imagen están mal.** → Descartada: `piloto-ok` cumple las seis políticas
   y no hubo cambios; el error habla de un webhook, no del recurso.
2. **Un problema de permisos o de cuota del namespace.** → Descartada: el mensaje es de
   `failed calling webhook`, no de `forbidden` ni de `exceeded quota`.
3. **El webhook de Kyverno no responde.** → Confirmada: `connection refused` hacia
   `kyverno-svc.kyverno.svc:443`, y `kubectl -n kyverno get endpoints kyverno-svc` muestra
   `<none>`.

## Comandos de diagnóstico

```bash
# 1. ¿Qué dice el error exactamente? (webhook, dirección, motivo)
kubectl -n equipo-piloto rollout restart deploy/piloto-ok

# 2. ¿El servicio del webhook tiene a alguien detrás?
kubectl -n kyverno get endpoints kyverno-svc
kubectl -n kyverno get deploy,pods                     # los pods pueden estar Running
kubectl -n kyverno get svc kyverno-svc -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n kyverno get pods --show-labels              # ¿coinciden las etiquetas con el selector?

# 3. ¿Qué webhooks siguen registrados y qué namespaces alcanzan? (mapa del impacto)
kubectl get validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg -o json \
  | jq '(.webhooks // [])[] | {name, failurePolicy, namespaceSelector, rules: [.rules[].resources]}'

# 4. Comprobar quién sí y quién no puede desplegar
for ns in equipo-piloto legacy-tramites apps-modernas; do
  echo "== $ns"; kubectl -n $ns get deploy -o name | head -1 | xargs -I{} kubectl -n $ns rollout restart {} 2>&1 | tail -1
done
```

## Mapa del impacto

El radio lo define la `ValidatingWebhookConfiguration`, **no la política**.

| Entrada del webhook | `failurePolicy` | Namespaces que alcanza | Efecto con el servicio caído |
|---|---|---|---|
| `vpol.validate.kyverno.svc-fail-…` (políticas `-enforce`) | `Fail` | Solo los que tienen `politicas.curso.lab/modo: enforce` → `equipo-piloto` | **Bloquea** crear o modificar Deployments, ReplicaSets, Pods, Jobs, etc. |
| `vpol.validate.kyverno.svc-ignore-…` (políticas Audit) | `Ignore` | Todos, menos `kube-system`, `kube-public`, `kube-node-lease`, `local-path-storage` y `kyverno` | **Deja pasar sin evaluar**: se despliega, pero sin auditoría |

Verificado en el ejercicio: `equipo-piloto` bloqueado; `legacy-tramites` y `apps-modernas`
desplegaron con normalidad. Lo que ya estaba corriendo no se vio afectado.

## Causa raíz

El `Service` `kyverno-svc` perdió sus endpoints (su selector dejó de coincidir con los pods del
admission controller). Los webhooks siguieron **registrados** y con `failurePolicy: Fail`, así
que el API server, al no obtener respuesta, rechazó las peticiones del radio del selector sin
evaluarlas. Que `piloto-ok` cumpla las políticas es irrelevante: no hay quién lo diga.

> Variante distinta, para no confundirla: si el admission controller se **apaga de forma
> ordenada** (por ejemplo, escalado a 0), Kyverno retira sus propios webhooks y el clúster queda
> *fail-open*: sin control, pero sin bloqueo. El bloqueo ocurre cuando el webhook **queda
> registrado y no responde**.

## Arreglo

```bash
# Restaurar el selector del Service
kubectl -n kyverno patch svc kyverno-svc --type=merge \
  -p '{"spec":{"selector":{"app.kubernetes.io/component":"admission-controller"}}}'

# Verificar: 3 IPs en el endpoint
kubectl -n kyverno get endpoints kyverno-svc

# Verificar el servicio del equipo
kubectl -n equipo-piloto rollout restart deploy/piloto-ok
kubectl -n equipo-piloto rollout status deploy/piloto-ok
```

Si no se recuerda el selector original: `kubectl -n kyverno get pods --show-labels` o
`helm get manifest kyverno -n kyverno`. Alternativa: `make kyverno` vuelve a aplicar el chart.

El arreglo fue posible porque el namespace `kyverno` está **excluido** del webhook. Si no lo
estuviera, la propia corrección habría sido rechazada (deadlock).

## Procedimiento de emergencia (si Kyverno no vuelve)

Si el admission controller no puede volver (imagen que no descarga, nodo caído) y hay equipos
bloqueados:

1. Declarar el incidente y avisar a los equipos afectados.
2. Eliminar **solo la entrada `Fail`** de `kyverno-resource-validating-webhook-cfg` (o, en último
   caso, la configuración completa). El API server deja de llamar a Kyverno.
3. Confirmar que se puede desplegar.
4. Resolver la causa de fondo. Kyverno recrea los webhooks al volver.

**Riesgo asumido:** mientras no haya webhook, **entra cualquier cosa**, incluido lo que las
políticas prohíben (privilegiados, hostPath, `:latest`). Por eso: pedir aprobación o informar de
inmediato, dejar constancia de la ventana (hora de inicio y fin) y, cuando Kyverno vuelva,
revisar los `PolicyReport` para auditar lo que se creó en ese intervalo.

## Prevención

- **3 réplicas** del admission controller con `topologySpread` por zona y **PDB** (ya
  configurado en `platform/kyverno/values.yaml`).
- **Exclusión permanente** del namespace `kyverno` y de los de sistema en el webhook.
- **Alerta sobre los endpoints del servicio**, no solo sobre los pods: un pod `Running` con el
  servicio sin endpoints es invisible para una alerta de pods (se implementa cuando haya
  Prometheus).
- Alertar también si **desaparecen** las `ValidatingWebhookConfiguration` de Kyverno: es el
  modo de falla silencioso (fail-open).
- Regla de diseño: **`Fail` solo para políticas de seguridad críticas**; las de buenas
  prácticas (`:latest`, límites de memoria) van con `Ignore`.
- Adopción gradual: Enforce solo en namespaces cuyo reporte de cumplimiento esté en cero, para
  que la caída de Kyverno afecte a pocos equipos.