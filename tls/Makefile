HOSTS      := litellm.umairkhancis.test dex.umairkhancis.test
LOCAL_DIR  := local
PEMS       := $(LOCAL_DIR)/gateway.pem $(LOCAL_DIR)/gateway-key.pem $(LOCAL_DIR)/cacert.pem $(LOCAL_DIR)/rootCA.pem

.PHONY: up generate seed hosts clean help

help:
	@echo "Targets:"
	@echo "  make up        Full setup: /etc/hosts + certs + Docker volume (one sudo prompt up front)"
	@echo "  make generate  Generate pem files into $(LOCAL_DIR)/"
	@echo "  make seed      Create infra-certs volume and copy pems into it"
	@echo "  make hosts     Append entries to /etc/hosts (uses sudo)"
	@echo "  make clean     Remove local pems and infra-certs volume"

up:
	@echo "Caching sudo credentials (needed for /etc/hosts)..."
	@sudo -v
	@$(MAKE) --no-print-directory hosts
	@$(MAKE) --no-print-directory generate
	@$(MAKE) --no-print-directory seed
	@echo
	@echo "✓ Setup complete: /etc/hosts mapped, certs generated, infra-certs volume seeded."

generate: $(PEMS)

$(PEMS):
	@command -v mkcert >/dev/null || { echo "Install mkcert: brew install mkcert nss"; exit 1; }
	@mkdir -p $(LOCAL_DIR)
	@mkcert -install
	@cd $(LOCAL_DIR) && mkcert -cert-file gateway.pem -key-file gateway-key.pem $(HOSTS)
	@cp "$$(mkcert -CAROOT)/rootCA.pem" $(LOCAL_DIR)/cacert.pem
	@cp "$$(mkcert -CAROOT)/rootCA.pem" $(LOCAL_DIR)/rootCA.pem
	@chmod 600 $(LOCAL_DIR)/gateway-key.pem
	@chmod 644 $(LOCAL_DIR)/gateway.pem $(LOCAL_DIR)/cacert.pem $(LOCAL_DIR)/rootCA.pem

seed:
	@docker volume inspect infra-certs >/dev/null 2>&1 || docker volume create infra-certs
	@docker compose up --force-recreate

hosts:
	@line="127.0.0.1 $(HOSTS)"; \
	if grep -qF "$$line" /etc/hosts; then \
	  echo "/etc/hosts already has: $$line"; \
	else \
	  echo "$$line" | sudo tee -a /etc/hosts >/dev/null; \
	  echo "Added to /etc/hosts: $$line"; \
	fi

clean:
	rm -f $(LOCAL_DIR)/*.pem
	-docker volume rm infra-certs
