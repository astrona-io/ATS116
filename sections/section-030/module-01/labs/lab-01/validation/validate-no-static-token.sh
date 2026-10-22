#!/usr/bin/env bash
# PASS when no OpenBao token is written into the inventory pod spec or its ConfigMaps.
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

SPEC="$(kubectl -n proxy-demo get deployment inventory -o json; kubectl -n proxy-demo get configmaps -o json)"
if printf '%s' "$SPEC" | grep -qE 's\.[A-Za-z0-9]{20,}|hvs\.|"BAO_TOKEN"|"VAULT_TOKEN"|token_file|X-Vault-Token'; then
  echo "FAIL: a token, a token variable or a token_file method is in the Deployment or a ConfigMap."
  exit 1
fi
ROOT="$(root_token)"
if printf '%s' "$SPEC" | grep -qF "$ROOT"; then
  echo "FAIL: the root token is in the Deployment or a ConfigMap."
  exit 1
fi
echo "PASS: no token is stored in the pod spec or its ConfigMaps."
exit 0
