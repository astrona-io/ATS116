#!/usr/bin/env bash
# PASS when the script still logs in with AppRole and holds no token.
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

SCRIPT="$(kubectl -n apicapstone get configmap report-script -o jsonpath='{.data.report\.sh}')"
if ! printf '%s' "$SCRIPT" | grep -q "auth/approle/login"; then
  echo "FAIL: the script no longer logs in with AppRole."
  exit 1
fi
if printf '%s' "$SCRIPT" | grep -qF "$(root_token)" || printf '%s' "$SCRIPT" | grep -qE 's\.[A-Za-z0-9]{20,}'; then
  echo "FAIL: a token is written into the script."
  exit 1
fi
POLICIES="$(bao_root read -format=json auth/approle/role/report | jq -r '.data.token_policies | join(",")')"
if [ "$POLICIES" != "inventory-lister" ]; then
  echo "FAIL: the AppRole report grants '$POLICIES' instead of inventory-lister."
  exit 1
fi
echo "PASS: the script logs in with AppRole and the role is unchanged."
exit 0
