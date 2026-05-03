# Swapping the Model Runtime Layer

The active runtime is controlled by the local model entries in `config.yaml`.
Each swap is: stop old runtime → replace the local model block → start new runtime → restart LiteLLM.

```bash
docker compose restart litellm   # reload config after every swap
```

---

## DMR (Docker Model Runner)

Zero setup — built into Docker Desktop. Default runtime.

**Pull models:**
```bash
docker model pull ai/llama3.2
docker model pull ai/qwen2.5
docker model pull ai/gemma3
```

**config.yaml local model block:**
```yaml
  # ── Local models — active runtime: DMR ──────────────────────────────────
  - model_name: llama3.2
    litellm_params:
      model: openai/docker.io/ai/llama3.2:latest
      api_base: http://model-runner.docker.internal:12434/engines/v1  # DMR
      api_key: dummy

  - model_name: qwen2.5
    litellm_params:
      model: openai/docker.io/ai/qwen2.5:latest
      api_base: http://model-runner.docker.internal:12434/engines/v1  # DMR
      api_key: dummy

  - model_name: gemma3
    litellm_params:
      model: openai/docker.io/ai/gemma3:latest
      api_base: http://model-runner.docker.internal:12434/engines/v1  # DMR
      api_key: dummy
```

---

## Ollama

Recommended for Mac (Metal) and Linux+NVIDIA. Manages models automatically.

**Start runtime:**
```bash
# Mac native (Metal — recommended)
cd ../model-runtime && make up RUNTIME=ollama MODE=native

# Container (CPU on Mac, GPU auto-detected on Linux)
cd ../model-runtime && make up RUNTIME=ollama
```

**Pull models:**
```bash
# native
ollama pull llama3.2 && ollama pull qwen2.5:7b && ollama pull gemma3:4b

# container
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull gemma3:4b
```

**config.yaml local model block:**
```yaml
  # ── Local models — active runtime: Ollama ───────────────────────────────
  - model_name: llama3.2
    litellm_params:
      model: openai/llama3.2
      api_base: http://host.docker.internal:11434/v1  # Ollama
      api_key: dummy

  - model_name: qwen2.5
    litellm_params:
      model: openai/qwen2.5:7b
      api_base: http://host.docker.internal:11434/v1  # Ollama
      api_key: dummy

  - model_name: gemma3
    litellm_params:
      model: openai/gemma3:4b
      api_base: http://host.docker.internal:11434/v1  # Ollama
      api_key: dummy
```

---

## llama.cpp

Serves one GGUF file at a time. Ignores the model name in requests — whatever
GGUF is loaded is what gets served. Only expose one model_name entry at a time.

**Download a GGUF** into `../model-runtime/llamacpp/models/` (e.g. from huggingface.co).

**Start runtime:**
```bash
# Mac native (Metal — recommended)
LLAMACPP_MODEL=llama-3.2-3b-instruct-q4_k_m.gguf \
  cd ../model-runtime && make up RUNTIME=llamacpp MODE=native

# Container (CPU on Mac, GPU auto-detected on Linux)
LLAMACPP_MODEL=llama-3.2-3b-instruct-q4_k_m.gguf \
  cd ../model-runtime && make up RUNTIME=llamacpp
```

**config.yaml local model block** (one entry — the loaded GGUF):
```yaml
  # ── Local models — active runtime: llama.cpp ────────────────────────────
  # llama.cpp serves one GGUF at a time — update model_name to match loaded file.
  - model_name: llama3.2
    litellm_params:
      model: openai/llama3.2
      api_base: http://host.docker.internal:8080/v1  # llama.cpp
      api_key: dummy
```

---

## vLLM

Linux + NVIDIA only. Serves one HuggingFace model at a time.
Set `VLLM_SERVED_MODEL_NAME` to match the `model_name` in config.yaml.

**Configure** `../model-runtime/.env`:
```bash
VLLM_MODEL=meta-llama/Llama-3.2-3B-Instruct   # HuggingFace model ID
VLLM_SERVED_MODEL_NAME=llama3.2                # must match model_name below
HF_TOKEN=hf_...                                # required for gated models
```

**Start runtime:**
```bash
cd ../model-runtime && make up RUNTIME=vllm
```

**config.yaml local model block** (one entry — the loaded model):
```yaml
  # ── Local models — active runtime: vLLM ─────────────────────────────────
  # model_name must match VLLM_SERVED_MODEL_NAME in model-runtime/.env
  - model_name: llama3.2
    litellm_params:
      model: openai/llama3.2
      api_base: http://host.docker.internal:8000/v1  # vLLM
      api_key: dummy
```
