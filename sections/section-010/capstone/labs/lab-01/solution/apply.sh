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

kubectl -n apicapstone create configmap report-script --from-file=report.sh=/dev/stdin --dry-run=client -o yaml <<'SCRIPT' | kubectl apply -f -
#!/bin/sh
# Lists every secret under secret/inventory and prints its fields.
set -eu
API="http://openbao.openbao.svc:8200/v1"
ROLE_ID="$(cat /etc/approle/role-id)"
SECRET_ID="$(cat /etc/approle/secret-id)"

LOGIN="$(curl -s -X POST --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" "$API/auth/approle/login")"
TOKEN="$(printf '%s' "$LOGIN" | jq -r '.auth.client_token')"

KEYS="$(curl -s -X LIST -H "X-Vault-Token: $TOKEN" "$API/secret/metadata/inventory" | jq -r '.data.keys[]')"
for key in $KEYS; do
  FIELDS="$(curl -s -H "X-Vault-Token: $TOKEN" "$API/secret/data/inventory/$key" | jq -c '.data.data')"
  echo "$key: $FIELDS"
done
echo "REPORT OK"
SCRIPT
