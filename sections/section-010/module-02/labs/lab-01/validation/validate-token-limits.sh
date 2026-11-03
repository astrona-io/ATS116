#!/usr/bin/env bash
# PASS when the token has a 15 minute TTL and five uses, and has not been used.
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
INFO="$(openbao_api POST auth/token/lookup "$(root_token)" "{\"token\":\"$TOKEN\"}")"
CREATION_TTL="$(printf '%s' "$INFO" | jq -r '.data.creation_ttl // empty')"
USES="$(printf '%s' "$INFO" | jq -r '.data.num_uses // empty')"
if [ "$CREATION_TTL" != "900" ]; then
  echo "FAIL: the token has a creation TTL of '$CREATION_TTL' seconds, expected 900 (15m)."
  exit 1
fi
if [ "$USES" != "5" ]; then
  echo "FAIL: the token has '$USES' uses left, expected 5. Create it with num_uses 5 and do not use it."
  exit 1
fi
echo "PASS: the token has a 15 minute TTL and five unused uses."
exit 0
