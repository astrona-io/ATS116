#!/usr/bin/env bash
# Runs before the reference solution is applied by `astrona test`.
# Waits until OpenBao answers as an unsealed, active node, and until the agent
# injector (section 040 only) is ready.
set -eu

for _ in $(seq 1 90); do
  code="$(kubectl -n clients exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}' \
    http://openbao.openbao.svc:8200/v1/sys/health 2>/dev/null || true)"
  [ "$code" = "200" ] && break
  sleep 2
done
if kubectl -n openbao get deployment openbao-agent-injector >/dev/null 2>&1; then
  kubectl -n openbao rollout status deployment/openbao-agent-injector --timeout=300s
fi
