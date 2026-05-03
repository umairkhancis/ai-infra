#!/usr/bin/env bash
set -euo pipefail

if ! command -v llama-server >/dev/null; then
  echo "llama-server not found. Install: brew install llama.cpp" >&2
  exit 1
fi

MODELS_DIR="$(cd "$(dirname "$0")" && pwd)/models"

if [[ -n "${LLAMACPP_MODEL:-}" && "${LLAMACPP_MODEL}" = /* ]]; then
  MODEL_PATH="${LLAMACPP_MODEL}"
elif [[ -n "${LLAMACPP_MODEL:-}" ]]; then
  MODEL_PATH="${MODELS_DIR}/${LLAMACPP_MODEL}"
else
  MODEL_PATH="$(find "$MODELS_DIR" -maxdepth 1 -name '*.gguf' | head -1)"
fi

if [[ -z "${MODEL_PATH:-}" ]] || [[ ! -f "$MODEL_PATH" ]]; then
  echo "No GGUF model found. Set LLAMACPP_MODEL or drop a .gguf into ${MODELS_DIR}/" >&2
  exit 1
fi

exec llama-server \
  --model "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers 999 \
  --ctx-size "${LLAMACPP_CTX_SIZE:-8192}"
