RUNTIME ?= ollama
MODE    ?= container

# Detect NVIDIA container runtime — adds GPU compose override on CUDA hosts.
HAS_GPU := $(shell docker info 2>/dev/null | grep -q nvidia && echo yes || echo no)
GPU_FLAGS = $(if $(filter yes,$(HAS_GPU)),-f $(RUNTIME)/docker-compose.gpu.yml,)

.PHONY: up down ps

up:
	@if [ "$(MODE)" = "native" ]; then \
		test -f $(RUNTIME)/native.sh || { echo "$(RUNTIME) has no native mode (container only)"; exit 1; }; \
		bash $(RUNTIME)/native.sh; \
	else \
		docker compose -f $(RUNTIME)/docker-compose.yml $(GPU_FLAGS) \
		  $$(test -f .env && echo --env-file .env) up -d; \
	fi

down:
	@if [ "$(MODE)" = "native" ]; then \
		echo "Stop the native process manually (Ctrl-C or kill the PID)"; \
	else \
		docker compose -f $(RUNTIME)/docker-compose.yml down; \
	fi

ps:
	@for r in ollama llamacpp vllm; do \
		printf "\n── $$r ──\n"; \
		docker compose -f $$r/docker-compose.yml ps 2>/dev/null || true; \
	done
