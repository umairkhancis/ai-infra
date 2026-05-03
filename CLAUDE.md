# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Local AI infrastructure stack — a Caddy edge proxy terminating TLS for an OIDC-protected LiteLLM gateway, with optional local model runtimes (Ollama / llama.cpp / vLLM / Docker Model Runner). Everything runs in Docker on the developer's machine; there is no application code, only Compose files, configs, and Makefiles wiring them together.

## Common commands

All orchestration is via Make. Each subproject has a standalone `make up` with precondition checks; the root Makefile chains them in dependency order.

```bash
# First-time setup on a fresh machine
make init             # cp ai-gateway/.env.example -> ai-gateway/.env (edit secrets)
make up               # certs + identity-provider + ai-gateway + edge
                      # (prompts once for sudo to write /etc/hosts; non-interactive after)

make down             # stop services (keeps volumes, network, certs)
make clean            # tear down everything: services + volumes + infra-net + certs
make ps               # status across subprojects

./smoke-test.sh       # 19 end-to-end checks: prerequisites, container health,
                      # volume mounts, host->Caddy HTTPS, container->container HTTPS
```

A subproject can be operated standalone:

```bash
make -C tls up                 # generate certs, seed infra-certs volume, /etc/hosts
make -C identity-provider up   # dex
make -C ai-gateway up          # litellm + postgres + redis
make -C edge up                # caddy
make -C llm-runtime up RUNTIME=ollama   # optional, MODE=native|container
```

## Architecture

Five subprojects connected by **two shared Docker resources** that must exist before consumers can start:

- **`infra-net`** — external bridge network. Every service joins it. Caddy uses network aliases so server-to-server TLS calls resolve the public hostnames internally.
- **`infra-certs`** — external named volume containing the TLS materials. `tls/` seeds it via a one-shot bootstrap container; consumers mount it read-only at `/certs:ro`.

The bootstrap pattern matters: services don't bind-mount `../tls/local`. They mount the named volume so the cert source can later be swapped (e.g., Vault) without changing consumers.

### Request path

```
client → https://litellm.umairkhancis.test → Caddy (edge) → litellm:4000 (ai-gateway)
                                                          → dex:5556 (identity-provider, via /sso/callback)
```

Caddy terminates TLS using `gateway.pem` from `infra-certs`, then reverse-proxies by hostname over `infra-net`. The same hostnames resolve via `/etc/hosts` (host→edge) and Docker network aliases (container→edge).

### Subproject roles

| Folder | Role | Key file |
|---|---|---|
| `tls/` | Local PKI bootstrap: mkcert CA install, cert generation into `tls/local/`, seed `infra-certs`, `/etc/hosts` | `Makefile` |
| `identity-provider/` | Dex OIDC issuer (in-memory, static users) | `dex/config.yaml` |
| `ai-gateway/` | LiteLLM proxy + Postgres + Redis. Routes `/v1/*` to model providers (Anthropic, local). UI at `/ui` is OIDC-protected. | `config.yaml` (model_list), `.env` (secrets) |
| `edge/` | Caddy reverse proxy, public entry point on :443 | `Caddyfile` |
| `llm-runtime/` | Optional local model serving. Multiple runtimes selected via `RUNTIME=` Make variable. | `Makefile` (`RUNTIME`, `MODE`) |

### Naming convention (intentional, not stylistic)

Folder and container names describe **roles**, not implementations: `ai-gateway` (not `litellm-gateway`), `edge` (not `caddy`), `identity-provider` (not `idp` or `dex`). The internals leak the implementation: the compose service inside `ai-gateway/` is still named `litellm:`, the image is `ghcr.io/berriai/litellm`, and `litellm-postgres` / `litellm-redis` keep the litellm prefix because they belong to litellm specifically (not the gateway abstraction). Cert filenames (`gateway.pem`, `gateway-key.pem`) and the internal mount path `/certs` are also intentionally kept — they're names, not folder references.

When renaming or adding a folder, preserve this distinction: role-named at the outside, implementation-named at the inside.

### Hostnames are baked in

`litellm.umairkhancis.test` and `dex.umairkhancis.test` appear in: `edge/Caddyfile`, `edge/docker-compose.yml` (network aliases), `identity-provider/dex/config.yaml` (issuer + redirect URI), `ai-gateway/.env` (OIDC endpoints + `PROXY_BASE_URL`), `tls/Makefile` (mkcert SANs). Changing the domain is currently a multi-file edit.

### LLM runtime swap

The active local runtime is determined by the `local models` block in `ai-gateway/config.yaml` (the `api_base` URL). To swap, update that block and `docker compose restart litellm` (or via `make -C ai-gateway` flow). See `ai-gateway/SWAP_RUNTIME_LAYER.md` for per-runtime config snippets.

## Subproject Makefile pattern

Every subproject Makefile uses the same target vocabulary: `up`, `down`, `ps`, `logs`, `help`. Each `up` checks preconditions (`infra-net`, `infra-certs`, `.env`) and exits with an actionable message pointing at the right command if missing. When adding a new service, follow this pattern so it composes with the root Makefile.

## OIDC client ID

`identity-provider/dex/config.yaml` registers an OIDC client `id: ai-gateway` (display name "AI Gateway"). The matching value lives in `ai-gateway/.env` as `GENERIC_CLIENT_ID=ai-gateway`. If you rename anything gateway-related, both sides must agree or admin-UI sign-in fails.
