#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this. Taken from solution.md - if one changes, change the other.
set -euo pipefail

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

LOGIN="$(openbao_api POST auth/userpass/login/deployer "" '{"password":"deployer-password"}')"
TOKEN="$(printf '%s' "$LOGIN" | jq -r '.auth.client_token')"
openbao_api POST secret/data/inventory/api "$TOKEN" '{"data":{"api_key":"api-key-from-deployer"}}' >/dev/null
WRAPPED="$(kubectl -n clients exec deploy/tester -- curl -s -H "X-Vault-Token: $TOKEN" -H "X-Vault-Wrap-TTL: 10m" \
  http://openbao.openbao.svc:8200/v1/secret/data/inventory/api)"
WRAP_TOKEN="$(printf '%s' "$WRAPPED" | jq -r '.wrap_info.token')"
kubectl -n api-demo create secret generic handover --from-literal=wrapping-token="$WRAP_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
