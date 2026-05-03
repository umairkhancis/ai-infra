.PHONY: help init up down clean ps network

help:
	@echo "Targets:"
	@echo "  make init     Create ai-gateway/.env from example (then edit secrets)"
	@echo "  make up       Bring up the core stack: tls + identity-provider + ai-gateway + edge"
	@echo "  make down     Stop services (keeps volumes, network, certs)"
	@echo "  make clean    Tear down everything: services, volumes, network, tls"
	@echo "  make ps       Status of core services"
	@echo
	@echo "Optional:"
	@echo "  make -C model-runtime up RUNTIME=ollama   # local model runtime"

init:
	@test -f ai-gateway/.env || cp ai-gateway/.env.example ai-gateway/.env
	@echo "→ ai-gateway/.env ready. Edit it to set secrets, then: make up"

up: network
	@$(MAKE) -C tls up
	@$(MAKE) -C identity-provider up
	@$(MAKE) -C ai-gateway up
	@$(MAKE) -C edge up
	@echo
	@echo "Stack up:"
	@echo "  https://litellm.umairkhancis.test/ui     (admin UI)"
	@echo "  https://dex.umairkhancis.test            (OIDC issuer)"

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
