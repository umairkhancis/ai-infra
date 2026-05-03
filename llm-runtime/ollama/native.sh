#!/usr/bin/env bash
set -euo pipefail

if ! command -v ollama >/dev/null; then
  echo "ollama not found. Install: brew install ollama" >&2
  exit 1
fi

# Bind on all interfaces so LiteLLM (in Docker) can reach this process via
# host.docker.internal:11434. Ollama's default is 127.0.0.1 only.
export OLLAMA_HOST=0.0.0.0:11434

if [[ -n "${OLLAMA_MODEL:-}" ]]; then
  ollama pull "$OLLAMA_MODEL"
fi

exec ollama serve
