# ADR-0001: kind como base del laboratorio local

- **Estado:** aceptada
- **Fecha:** 2026-09-28

## Contexto
El curso necesita clústeres locales, sin costo de nube, reproducibles con un comando, y con
dos clústeres simultáneos en el Módulo 8. El bloque de admisión (M1–M4) exige que el API
server se comporte como el upstream, porque se estudia la cadena de admisión y los webhooks.

## Opciones consideradas
1. **kind** — nodos como contenedores, Kubernetes upstream instalado con kubeadm.
2. **k3d** — k3s en contenedores: más liviano, trae Traefik y un datastore alternativo a etcd
   por defecto.
3. **minikube** — una VM o contenedor por clúster, orientado a un solo clúster de desarrollo.

## Decisión
kind v0.33.0 con imagen de nodo Kubernetes 1.36.4 fijada por digest.

## Criterios y por qué
- **Fidelidad al upstream (peso alto):** kind usa kubeadm y binarios oficiales; es lo que usa
  el propio proyecto Kubernetes para sus pruebas. k3s es una distribución certificada pero
  empaquetada distinto (un solo binario, componentes opcionales). Para estudiar admisión,
  fidelidad gana.
- **Multi-clúster en una laptop (alto):** kind y k3d lo resuelven igual de bien.
- **Consumo de RAM (medio):** k3d gana. Se compensa con `make pause` y el perfil ligero.
- **Registry local (medio):** ambos tienen patrón documentado.

## Consecuencias
- Más RAM por nodo que k3d. Se documenta el presupuesto por módulo.
- Los clústeres comparten la red Docker `kind`: el "multi-clúster" no simula latencia WAN ni
  dominios de falla reales. Hay que decirlo así en una entrevista.
- Cambiaría la decisión si la RAM disponible fuera menor a 8 GiB.
