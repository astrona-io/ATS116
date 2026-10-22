#!/usr/bin/env bash
# PASS when the app returns the inventory secret through the proxy, with no token of its own.
set -uo pipefail

# Lab-only: the root token lives in a Kubernetes Secret so scripts can use it.
root_token() { kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d; }
bao_root() {
  kubectl -n openbao exec -i openbao-0 -- \
    env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN="$(root_token)" bao "$@"
}
# openbao_api METHOD PATH TOKEN [JSON]: one HTTP API request from the tester pod.
openbao_api() {
  local method="$1" api_path="$2" token="$3" body="${4:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | kubectl -n clients exec -i deploy/tester -- \
      curl -s -X "$method" -H "X-Vault-Token: $token" --data-binary @- \
      "http://openbao.openbao.svc:8200/v1/$api_path"
  else
    kubectl -n clients exec deploy/tester -- \
      curl -s -X "$method" -H "X-Vault-Token: $token" \
      "http://openbao.openbao.svc:8200/v1/$api_path"
  fi
}
# app_get NAMESPACE PATH: a request to the inventory app's Service from the tester pod.
app_get() { kubectl -n clients exec deploy/tester -- curl -s --max-time 5 "http://inventory.$1.svc$2"; }

EXPECTED="$(bao_root kv get -field=api_key secret/inventory/config)"
for _ in $(seq 1 30); do
  BODY="$(app_get proxy-demo /config || true)"
  if [ "$(printf '%s' "$BODY" | jq -r '.data.data.api_key // empty' 2>/dev/null)" = "$EXPECTED" ]; then
    echo "PASS: the app reads secret/inventory/config through the proxy."
    exit 0
  fi
  sleep 3
done
echo "FAIL: http://inventory.proxy-demo/config does not return the secret. Last answer:"
printf '%s\n' "$BODY" | head -5
exit 1
