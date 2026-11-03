#!/usr/bin/env bash
# PASS when the token in Secret report-token has only inventory-lister (and default), not root.
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

TOKEN="$(kubectl -n api-demo get secret report-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)"
if [ -z "$TOKEN" ]; then
  echo "FAIL: Secret report-token with key token does not exist in namespace api-demo."
  exit 1
fi
INFO="$(openbao_api POST auth/token/lookup "$(root_token)" "{\"token\":\"$TOKEN\"}")"
POLICIES="$(printf '%s' "$INFO" | jq -r '.data.policies // empty | sort | join(",")')"
if [ -z "$POLICIES" ]; then
  echo "FAIL: OpenBao does not know the token in report-token. It may be revoked, used up or expired."
  exit 1
fi
if [ "$POLICIES" != "default,inventory-lister" ]; then
  echo "FAIL: the token has the policies '$POLICIES', expected default,inventory-lister."
  exit 1
fi
echo "PASS: the token has only the policies default and inventory-lister."
exit 0
