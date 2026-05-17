# ai-infra

Local AI infrastructure stack: TLS-fronted, OIDC-protected LiteLLM gateway with optional local model runtimes. Runs entirely in Docker on a developer's machine.

```
client ──► https://litellm.umairkhancis.test ──► edge (Caddy)  ──► ai-gateway (LiteLLM)
                                                         └──► identity-provider (Dex OIDC)
```

## Prerequisites

- Docker (Desktop / OrbStack / equivalent), running
- [`mkcert`](https://github.com/FiloSottile/mkcert) — `brew install mkcert nss`
- macOS or Linux

## Quick start

```bash
git clone <repo-url> ai-infra
cd ai-infra

make up
```

That's it. `make up` does everything from a fresh clone:

1. Generates `ai-gateway/.env` with random `LITELLM_MASTER_KEY` and `POSTGRES_PASSWORD`; the OIDC/Dex/LiteLLM values are pre-wired (no manual editing).
2. Prompts once for an Anthropic API key (Enter to skip — the stack still starts; Anthropic-routed `/v1/*` calls will return an auth error until you set one).
3. Installs `mkcert` via Homebrew if missing (macOS only).
4. Explains the two local system changes it's about to make (`/etc/hosts` entries + local CA install), then prompts once for sudo to edit `/etc/hosts`.
5. Generates TLS certs, seeds the shared Docker volume, and starts the four core services in dependency order.

When it finishes:

- **Admin UI:** https://litellm.umairkhancis.test/ui (sign in via Dex; default test user `test@example.com` / `test`)
- **OIDC issuer:** https://dex.umairkhancis.test/.well-known/openid-configuration
- **API:** `https://litellm.umairkhancis.test/v1/*` (auth via virtual keys generated in the admin UI)

## Verify

```bash
./smoke-test.sh
```

Runs 19 checks: prerequisites, container health, volume mounts, host→Caddy HTTPS, and container→container HTTPS with cert validation.

## Secrets (`ai-gateway/.env`)

`make up` generates this file automatically from `ai-gateway/.env.example` on a fresh clone. You only ever need to touch it to add provider credentials.

| Variable | Set by | How |
|---|---|---|
| `LITELLM_MASTER_KEY` | `make init` | random `sk-$(openssl rand -hex 32)` |
| `POSTGRES_PASSWORD` | `make init` | random `openssl rand -hex 24` |
| `ANTHROPIC_API_KEY` | `make init` (interactive prompt) | paste yours, or Enter to skip |
| `PROXY_BASE_URL`, `GENERIC_*` | `.env.example` defaults | wired for local Dex; no edits needed |

If you skipped the Anthropic key at setup time, add it later:

```bash
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ai-gateway/.env  # or edit the existing line
make -C ai-gateway down && make -C ai-gateway up
```

Other providers (`OPENAI_API_KEY`, `AZURE_API_KEY`, …) are commented in the example — uncomment what you need and add the matching `model_list` entries to `ai-gateway/config.yaml`.

## Repository layout

```
ai-infra/
├── tls/                   PKI bootstrap (mkcert + /etc/hosts + infra-certs volume)
├── identity-provider/     Dex OIDC issuer
├── ai-gateway/            LiteLLM proxy + Postgres + Redis
├── edge/                  Caddy reverse proxy (TLS termination, hostname routing)
├── llm-runtime/           Optional local model runtimes (Ollama / llama.cpp / vLLM / DMR)
├── Makefile               Root orchestrator
└── smoke-test.sh          End-to-end checks
```

Each subproject has its own `Makefile` with the same vocabulary (`up`, `down`, `ps`, `logs`) and can be operated standalone.

## Common operations

```bash
# Top-level
make up           # bring up the core stack
make down         # stop services (keeps volumes, network, certs)
make clean        # tear down everything: services + volumes + infra-net + certs
make ps           # status across subprojects

# Per-subproject (run in any order, top-level make handles dependencies)
make -C ai-gateway logs
make -C edge restart    # via docker compose restart inside

# View Caddy / LiteLLM / Dex logs
docker logs -f infra-caddy
docker logs -f ai-gateway
docker logs -f identity-provider
```

## Local model runtimes (optional)

`ai-gateway/config.yaml` declares local model entries (e.g. `llama3.2`, `qwen2.5`, `gemma3`). The active runtime is whichever the `api_base` URL points at — Docker Model Runner by default.

```bash
make -C llm-runtime up RUNTIME=ollama MODE=native      # Mac native (Metal)
make -C llm-runtime up RUNTIME=ollama                  # container; GPU auto-detected on Linux
make -C llm-runtime up RUNTIME=llamacpp                # single GGUF; needs LLAMACPP_MODEL
make -C llm-runtime up RUNTIME=vllm                    # Linux + NVIDIA only
```

To swap runtimes, update the `local models` block in `ai-gateway/config.yaml` and restart LiteLLM. See [`ai-gateway/SWAP_RUNTIME_LAYER.md`](ai-gateway/SWAP_RUNTIME_LAYER.md) for per-runtime config snippets.

## On another machine

The hostnames (`litellm.umairkhancis.test`, `dex.umairkhancis.test`) are fake `.test` TLDs — they resolve via `/etc/hosts` only and work on any machine. The TLS certs are mkcert-issued by your local CA, which is machine-specific; `tls/Makefile` regenerates them from your local CA without any code changes.

## Troubleshooting

- **`Container name "X" already in use`** — leftover from an earlier run with different folder names. `docker rm -f <name>`, then `make up`.
- **`infra-certs not found`** — `make -C tls up` (or `make up` from root).
- **`infra-net not found`** — `docker network create infra-net` (also created by `make up`).
- **`/etc/hosts` entries missing** — `make -C tls hosts` (uses sudo).
- **Admin UI sign-in fails** — `GENERIC_CLIENT_ID` in `ai-gateway/.env` must match `staticClients[].id` in `identity-provider/dex/config.yaml` (currently `ai-gateway`).
