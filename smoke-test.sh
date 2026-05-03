#!/usr/bin/env bash
# Smoke test for the ai-infra workspace.
# Verifies prerequisites, container health, and end-to-end request paths.
# Run from anywhere: bash smoke-test.sh

set -uo pipefail

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

# -------------------- Prerequisites --------------------
section "Prerequisites"

run "docker daemon reachable" \
  docker info

run "network 'infra-net' exists  (one-time: docker network create infra-net)" \
  docker network inspect infra-net

run "volume 'infra-certs' exists  (one-time: docker volume create infra-certs)" \
  docker volume inspect infra-certs

run "volume 'infra-certs' contains gateway.pem  (run: cd tls && docker compose up)" \
  docker run --rm -v infra-certs:/c alpine:3.20 test -f /c/gateway.pem

run "volume 'infra-certs' contains gateway-key.pem" \
  docker run --rm -v infra-certs:/c alpine:3.20 test -f /c/gateway-key.pem

run "volume 'infra-certs' contains cacert.pem" \
  docker run --rm -v infra-certs:/c alpine:3.20 test -f /c/cacert.pem

run "/etc/hosts maps litellm.umairkhancis.test -> 127.0.0.1" \
  grep -qE "^127\.0\.0\.1.*litellm\.umairkhancis\.test" /etc/hosts

run "/etc/hosts maps dex.umairkhancis.test -> 127.0.0.1" \
  grep -qE "^127\.0\.0\.1.*dex\.umairkhancis\.test" /etc/hosts

# -------------------- Container health --------------------
section "Container health"

for name in infra-caddy identity-provider ai-gateway litellm-postgres litellm-redis; do
  run "container '$name' is running" \
    bash -c "docker ps --format '{{.Names}}' | grep -qx '$name'"
done

# -------------------- Mounts --------------------
section "Named-volume mounts"

run "Caddy container sees /certs/gateway.pem from infra-certs" \
  docker exec infra-caddy sh -c 'test -f /certs/gateway.pem'

run "LiteLLM container sees /certs/cacert.pem from infra-certs" \
  docker exec ai-gateway sh -c 'test -f /certs/cacert.pem'

# -------------------- Functional: host -> Caddy --------------------
section "Host -> Caddy (HTTPS via /etc/hosts)"

run "GET https://litellm.umairkhancis.test/health/liveliness -> 200" \
  bash -c "curl -fsS -o /dev/null https://litellm.umairkhancis.test/health/liveliness"

run "GET https://dex.umairkhancis.test/.well-known/openid-configuration -> 200" \
  bash -c "curl -fsS -o /dev/null https://dex.umairkhancis.test/.well-known/openid-configuration"

# -------------------- Functional: server-to-server inside infra-net --------------------
section "Container -> Caddy (HTTPS via Docker DNS alias on infra-net)"

run "LiteLLM resolves dex.umairkhancis.test via Docker DNS (alias on infra-net)" \
  docker exec ai-gateway python -c "import socket; socket.gethostbyname('dex.umairkhancis.test')"

run "LiteLLM -> Dex HTTPS call validates against /certs/cacert.pem trust bundle" \
  docker exec ai-gateway python -c "import urllib.request; urllib.request.urlopen('https://dex.umairkhancis.test/.well-known/openid-configuration', timeout=5).read()"

# -------------------- Summary --------------------
section "Summary"
printf "Passed: %d\nFailed: %d\n" "$pass" "$fail"
if ((fail > 0)); then
  printf "\nFailed tests:\n"
  printf "  - %s\n" "${failed_tests[@]}"
  exit 1
fi
exit 0
