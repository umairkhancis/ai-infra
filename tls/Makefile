HOSTS      := litellm.umairkhancis.test dex.umairkhancis.test
LOCAL_DIR  := local
PEMS       := $(LOCAL_DIR)/gateway.pem $(LOCAL_DIR)/gateway-key.pem $(LOCAL_DIR)/cacert.pem $(LOCAL_DIR)/rootCA.pem

.PHONY: up generate seed hosts clean help install-mkcert explain

help:
	@echo "Targets:"
	@echo "  make up        Full setup: install mkcert (if missing), explain & edit /etc/hosts,"
	@echo "                 generate certs, seed the infra-certs Docker volume."
	@echo "  make generate  Generate pem files into $(LOCAL_DIR)/"
	@echo "  make seed      Create infra-certs volume and copy pems into it"
	@echo "  make hosts     Append entries to /etc/hosts (uses sudo)"
	@echo "  make clean     Remove local pems and infra-certs volume"

up: install-mkcert explain
	@echo "Caching sudo credentials (needed for /etc/hosts)..."
	@sudo -v
	@$(MAKE) --no-print-directory hosts
	@$(MAKE) --no-print-directory generate
	@$(MAKE) --no-print-directory seed
	@echo
	@echo "✓ Setup complete: /etc/hosts mapped, certs generated, infra-certs volume seeded."

# Auto-install mkcert on macOS via Homebrew. On other OSes, print install hints and bail.
install-mkcert:
	@if command -v mkcert >/dev/null 2>&1; then exit 0; fi; \
	echo "mkcert not found — attempting to install..."; \
	case "$$(uname -s)" in \
	  Darwin) \
	    if ! command -v brew >/dev/null 2>&1; then \
	      echo "ERROR: Homebrew not found. Install from https://brew.sh, then re-run 'make up'."; \
	      exit 1; \
	    fi; \
	    brew install mkcert nss ;; \
	  Linux) \
	    echo "ERROR: mkcert auto-install is not supported on Linux."; \
	    echo "Install manually, then re-run 'make up':"; \
	    echo "  Ubuntu/Debian: sudo apt install libnss3-tools && download mkcert from"; \
	    echo "                 https://github.com/FiloSottile/mkcert/releases"; \
	    echo "  Fedora:        sudo dnf install nss-tools && download mkcert binary"; \
	    exit 1 ;; \
	  *) \
	    echo "ERROR: unsupported OS. Install mkcert manually:"; \
	    echo "  https://github.com/FiloSottile/mkcert#installation"; \
	    exit 1 ;; \
	esac

# One-time explanation block — printed before any sudo / system change happens.
explain:
	@echo
	@echo "─── About to make two local system changes ────────────────"
	@echo
	@echo "This stack uses real-looking hostnames + TLS instead of"
	@echo "localhost:<port>, so the local setup mirrors a production"
	@echo "deployment. Two one-time changes are needed (both reversed"
	@echo "by 'make clean'):"
	@echo
	@echo "  1. /etc/hosts (sudo prompt below)"
	@echo "     Adds:  127.0.0.1 $(HOSTS)"
	@echo "     Why hostnames instead of localhost:port?"
	@echo "       - TLS certs are issued for hostnames, not IPs"
	@echo "       - OIDC redirect URIs and cookie scopes match across services"
	@echo "       - Caddy can route by hostname (one port, many services)"
	@echo "       - You'd use real DNS in prod; this is the local equivalent"
	@echo
	@echo "  2. Local trust store (mkcert may prompt next)"
	@echo "     Installs a per-machine root CA so your browser trusts"
	@echo "     the self-signed certs. The CA never leaves your machine"
	@echo "     and is unique to it."
	@echo

generate: $(PEMS)

$(PEMS):
	@command -v mkcert >/dev/null || { echo "Install mkcert: brew install mkcert nss"; exit 1; }
	@mkdir -p $(LOCAL_DIR)
	@mkcert -install
	@cd $(LOCAL_DIR) && mkcert -cert-file gateway.pem -key-file gateway-key.pem $(HOSTS)
	@cp "$$(mkcert -CAROOT)/rootCA.pem" $(LOCAL_DIR)/rootCA.pem
	@# cacert.pem = mkcert root + public CAs. Lets containers verify both
	@# internal hostnames (signed by mkcert) and public APIs (Anthropic, OpenAI).
	@cp "$$(mkcert -CAROOT)/rootCA.pem" $(LOCAL_DIR)/cacert.pem
	@if   [ -f /etc/ssl/cert.pem ];                then cat /etc/ssl/cert.pem               >> $(LOCAL_DIR)/cacert.pem; \
	 elif [ -f /etc/ssl/certs/ca-certificates.crt ]; then cat /etc/ssl/certs/ca-certificates.crt >> $(LOCAL_DIR)/cacert.pem; \
	 else echo "WARNING: no system CA bundle found; cacert.pem will only trust mkcert"; fi
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
	-docker compose down
	rm -f $(LOCAL_DIR)/*.pem
	-docker volume rm infra-certs
