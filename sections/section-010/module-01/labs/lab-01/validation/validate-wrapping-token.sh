#!/usr/bin/env bash
# PASS when Secret handover holds an unused wrapping token for secret/data/inventory/api with a 10 minute TTL.
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

WRAP_TOKEN="$(kubectl -n api-demo get secret handover -o jsonpath='{.data.wrapping-token}' 2>/dev/null | base64 -d)"
if [ -z "$WRAP_TOKEN" ]; then
  echo "FAIL: Secret handover with key wrapping-token does not exist in namespace api-demo."
  exit 1
fi
INFO="$(openbao_api POST sys/wrapping/lookup "" "{\"token\":\"$WRAP_TOKEN\"}")"
PATH_SEEN="$(printf '%s' "$INFO" | jq -r '.data.creation_path // empty')"
TTL_SEEN="$(printf '%s' "$INFO" | jq -r '.data.creation_ttl // empty')"
if [ "$PATH_SEEN" != "secret/data/inventory/api" ]; then
  echo "FAIL: the wrapping token is unknown, already used, or wraps '$PATH_SEEN' instead of secret/data/inventory/api."
  exit 1
fi
if [ "$TTL_SEEN" != "600" ]; then
  echo "FAIL: the wrapping token has a TTL of '$TTL_SEEN' seconds, expected 600 (10m)."
  exit 1
fi
echo "PASS: Secret handover holds an unused 10 minute wrapping token for secret/data/inventory/api."
exit 0
