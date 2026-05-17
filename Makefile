.PHONY: help init up down clean ps network

ENV_FILE := ai-gateway/.env
ENV_TEMPLATE := ai-gateway/.env.example

help:
	@echo "Targets:"
	@echo "  make up       One-command setup: generates secrets (prompts for Anthropic key),"
	@echo "                installs mkcert if missing, edits /etc/hosts (sudo prompt),"
	@echo "                then brings up tls + identity-provider + ai-gateway + edge."
	@echo "  make init     Generate $(ENV_FILE) (run by 'make up' if it doesn't exist)."
	@echo "  make down     Stop services (keeps volumes, network, certs)."
	@echo "  make clean    Tear down everything: services, volumes, network, tls."
	@echo "  make ps       Status of core services."
	@echo
	@echo "Optional:"
	@echo "  make -C llm-runtime up RUNTIME=ollama   # local model runtime"

up: $(ENV_FILE) network
	@$(MAKE) -C tls up
	@$(MAKE) -C identity-provider up
	@$(MAKE) -C ai-gateway up
	@$(MAKE) -C edge up
	@echo
	@echo "Stack up:"
	@echo "  https://litellm.umairkhancis.test/ui     (admin UI)"
	@echo "  https://dex.umairkhancis.test            (OIDC issuer)"
	@echo "  Default test login: test@example.com / test"

# Auto-generate .env on a fresh clone. Make only runs this when the file is missing.
$(ENV_FILE):
	@$(MAKE) --no-print-directory init

init:
	@if [ -f $(ENV_FILE) ]; then \
	  echo "→ $(ENV_FILE) already exists; leaving alone."; \
	  exit 0; \
	fi; \
	command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl not found (needed to generate secrets)."; exit 1; }; \
	echo; \
	echo "─── Anthropic API key (optional) ──────────────────────────"; \
	echo "Used to route requests to Claude models through the gateway."; \
	echo "Leave blank to skip — the stack still starts and the admin UI works,"; \
	echo "but any /v1/* call to an Anthropic model will return an auth error"; \
	echo "until you add a key to $(ENV_FILE) and restart the gateway."; \
	echo "Get one at https://console.anthropic.com/"; \
	echo; \
	printf "Anthropic API key (Enter to skip): "; \
	read ANTHROPIC_KEY; \
	MASTER_KEY="sk-$$(openssl rand -hex 32)"; \
	PG_PASSWORD="$$(openssl rand -hex 24)"; \
	sed -e "s|sk-CHANGE-ME|$$MASTER_KEY|" \
	    -e "s|POSTGRES_PASSWORD=CHANGE-ME|POSTGRES_PASSWORD=$$PG_PASSWORD|" \
	    -e "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$$ANTHROPIC_KEY|" \
	    $(ENV_TEMPLATE) > $(ENV_FILE); \
	chmod 600 $(ENV_FILE); \
	echo "✓ $(ENV_FILE) generated (random LITELLM_MASTER_KEY + POSTGRES_PASSWORD)."

network:
	@docker network inspect infra-net >/dev/null 2>&1 || docker network create infra-net

down:
	-@$(MAKE) -C edge down
	-@$(MAKE) -C ai-gateway down
	-@$(MAKE) -C identity-provider down

clean: down
	-@$(MAKE) -C tls clean
	-docker network rm infra-net

ps:
	@for d in identity-provider ai-gateway edge; do \
	  printf "\n── $$d ──\n"; \
	  $(MAKE) -C $$d ps 2>/dev/null || true; \
	done
