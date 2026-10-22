#!/usr/bin/env bash
# PASS when batch-reader reads only the inventory configuration.
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

POLICY="$(bao_root policy read batch-reader)"
if printf '%s' "$POLICY" | grep -qE '"\*"|sudo|secret/data/\*|secret/\*'; then
  echo "FAIL: batch-reader was widened with a wildcard path, a wildcard capability or sudo."
  exit 1
fi
if ! printf '%s' "$POLICY" | grep -q 'path "secret/data/inventory/config"'; then
  echo "FAIL: batch-reader has no rule for secret/data/inventory/config."
  exit 1
fi
POLICIES="$(bao_root read -format=json auth/approle/role/inventory-batch | jq -r '.data.token_policies | join(",")')"
[ "$POLICIES" = "batch-reader" ] || { echo "FAIL: AppRole inventory-batch grants '$POLICIES'."; exit 1; }
echo "PASS: batch-reader is narrow and the AppRole is unchanged."
exit 0
