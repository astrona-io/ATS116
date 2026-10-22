#!/usr/bin/env bash
# PASS when the audit log shows deployer, not root, writing secret/inventory/api.
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

LOG="$(kubectl -n openbao exec openbao-0 -- cat /openbao/logs/audit.log 2>/dev/null || true)"
if printf '%s\n' "$LOG" | grep '"type":"request"' | grep '"path":"secret/data/inventory/api"' \
     | grep -E '"operation":"(create|update)"' | grep -q '"display_name":"userpass-deployer"'; then
  echo "PASS: the audit log shows userpass-deployer writing secret/data/inventory/api."
  exit 0
fi
echo "FAIL: no audit entry shows the deployer token writing secret/data/inventory/api. Write it with the token from the userpass login, not the root token."
exit 1
