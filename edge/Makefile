.PHONY: help up down ps logs

help:
	@echo "Targets: up, down, ps, logs"

up:
	@docker network inspect infra-net >/dev/null 2>&1 || { echo "infra-net not found. Run from repo root: make up"; exit 1; }
	@docker volume inspect infra-certs >/dev/null 2>&1 || { echo "infra-certs not found. Run: cd ../tls && make up"; exit 1; }
	docker compose up -d

down:
	docker compose down

ps:
	@docker compose ps

logs:
	docker compose logs -f
