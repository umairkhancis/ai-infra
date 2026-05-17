#!/usr/bin/env bash
# Smoke test for ai-infra.
# Verifies the full default stack (postgres + redis + dex + litellm) is up
# and reachable at http://localhost:4000.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

pass=0
fail=0
failed_tests=()

run() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf "  [PASS] %s\n" "$name"
    pass=$((pass + 1))
  else
    printf "  [FAIL] %s\n" "$name"
    fail=$((fail + 1))
    failed_tests+=("$name")
  fi
}

section() {
  printf "\n== %s ==\n" "$1"
}

container_healthy() {
  local svc=$1
  local cid
  cid=$(docker compose ps -q "$svc" 2>/dev/null)
  [ -n "$cid" ] || return 1
  local status
  status=$(docker inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo none)
  [ "$status" = "healthy" ]
}

container_running() {
  local svc=$1
  local cid
  cid=$(docker compose ps -q "$svc" 2>/dev/null)
  [ -n "$cid" ] || return 1
  local status
  status=$(docker inspect --format '{{.State.Status}}' "$cid" 2>/dev/null || echo none)
  [ "$status" = "running" ]
}

# -------------------- Prerequisites --------------------
section "Prerequisites"

run "docker daemon reachable" \
  docker info

# -------------------- Services --------------------
section "Services"

run "postgres healthy" container_healthy postgres
run "redis healthy"    container_healthy redis
run "dex running"      container_running dex
run "litellm healthy"  container_healthy litellm

# -------------------- LiteLLM HTTP --------------------
section "LiteLLM HTTP (localhost:4000)"

run "GET /health/liveliness -> 200" \
  bash -c "curl -fsS -o /dev/null http://localhost:4000/health/liveliness"

run "GET /health/readiness -> 200" \
  bash -c "curl -fsS -o /dev/null http://localhost:4000/health/readiness"

run "GET /ui (admin UI reachable) -> 200" \
  bash -c "curl -fsS -o /dev/null http://localhost:4000/ui"

# -------------------- Dex OIDC discovery --------------------
section "Dex OIDC (localhost:5556)"

run "GET /.well-known/openid-configuration -> 200" \
  bash -c "curl -fsS -o /dev/null http://127.0.0.1:5556/.well-known/openid-configuration"

run "issuer claim is http://dex.localhost:5556" \
  bash -c "curl -fsS http://127.0.0.1:5556/.well-known/openid-configuration | grep -qE '\"issuer\":[[:space:]]*\"http://dex.localhost:5556\"'"

# -------------------- LiteLLM -> Dex reachability --------------------
# The trick: extra_hosts maps dex.localhost → host-gateway inside the litellm
# container, so back-channel OIDC token/userinfo calls reach Dex at the same
# URL the browser uses. If this breaks, OIDC sign-in will fail at the token
# exchange step.
section "LiteLLM container can reach Dex"

run "litellm container resolves dex.localhost to host-gateway" \
  bash -c "docker compose exec -T litellm python -c \"import socket; socket.gethostbyname('dex.localhost')\""

run "litellm -> http://dex.localhost:5556/.well-known/openid-configuration -> 200" \
  bash -c "docker compose exec -T litellm python -c \"import urllib.request; urllib.request.urlopen('http://dex.localhost:5556/.well-known/openid-configuration', timeout=5).read()\""

# -------------------- Virtual key creation --------------------
section "Virtual key creation"

if [ -f "$REPO_ROOT/.env" ]; then
  MASTER_KEY="$(grep -E '^LITELLM_MASTER_KEY=' "$REPO_ROOT/.env" | head -n1 | cut -d= -f2-)"
else
  MASTER_KEY="sk-CHANGE-ME"
fi

run "POST /key/generate with master key -> JSON with 'key'" \
  bash -c "curl -fsS -X POST http://localhost:4000/key/generate \
    -H 'Authorization: Bearer $MASTER_KEY' \
    -H 'Content-Type: application/json' \
    -d '{\"models\":[\"claude-haiku-4-5\"]}' | grep -q '\"key\"'"

# -------------------- Summary --------------------
section "Summary"
printf "Passed: %d\nFailed: %d\n" "$pass" "$fail"
if ((fail > 0)); then
  printf "\nFailed tests:\n"
  printf "  - %s\n" "${failed_tests[@]}"
  exit 1
fi
exit 0
