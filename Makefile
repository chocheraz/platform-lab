# Único punto de entrada del lab. `make` sin argumentos muestra la ayuda.
SHELL := /bin/bash
CLUSTER ?= plataforma
CTX     := kind-$(CLUSTER)
export PATH := $(CURDIR)/.bin:$(PATH)

.DEFAULT_GOAL := help
.PHONY: help tools doctor up down down-all pause resume status seed smoke reset

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n",$$1,$$2}'
	@echo "  Variable: CLUSTER=plataforma|satelite (por defecto: plataforma)"

tools: ## Instala kind, kubectl y helm fijados en ./.bin (con checksum)
	@scripts/install-tools.sh

doctor: ## Verifica que la máquina puede correr el lab
	@scripts/doctor.sh

up: ## Crea registry + clúster (idempotente)
	@scripts/cluster-up.sh $(CLUSTER)

down: ## Borra el clúster CLUSTER
	@scripts/cluster-down.sh $(CLUSTER)

down-all: ## Borra todos los clústeres y el registry
	@scripts/cluster-down.sh todo

pause: ## Detiene los nodos para liberar RAM (conserva estado)
	@scripts/lifecycle.sh pause $(CLUSTER)

resume: ## Reanuda los nodos y espera a que estén Ready
	@scripts/lifecycle.sh resume $(CLUSTER)

status: ## Clústeres, nodos, registry y consumo de memoria
	@scripts/status.sh

seed: ## Siembra las cargas legadas y modernas del Módulo 0
	kubectl --context $(CTX) apply -k workloads/
	kubectl --context $(CTX) -n apps-modernas rollout status deploy/portal-moderno --timeout=180s
	kubectl --context $(CTX) -n legacy-tramites rollout status deploy/portal-tramites --timeout=180s

smoke: ## Publica una imagen en el registry local y la despliega desde ahí
	@scripts/smoke-registry.sh $(CLUSTER)

reset: ## Destruye y reconstruye el punto de partida desde cero
	@scripts/cluster-down.sh $(CLUSTER)
	@scripts/cluster-up.sh $(CLUSTER)
	@$(MAKE) --no-print-directory seed CLUSTER=$(CLUSTER)
