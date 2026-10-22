#!/usr/bin/env bash
# PASS when the proxy port 8100 cannot be reached from outside the pod.
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

POD_IP="$(kubectl -n proxycapstone get pods -l app=inventory -o jsonpath='{.items[0].status.podIP}')"
if kubectl -n clients exec deploy/tester -- curl -s --max-time 3 -o /dev/null "http://$POD_IP:8100/v1/sys/health" 2>/dev/null; then
  echo "FAIL: http://$POD_IP:8100 answers from another pod. Bind the proxy listener to 127.0.0.1."
  exit 1
fi
if kubectl -n proxycapstone get service inventory -o jsonpath='{.spec.ports[*].port}' | grep -qw 8100; then
  echo "FAIL: the Service exposes port 8100."
  exit 1
fi
echo "PASS: only containers in the pod can reach the proxy."
exit 0
