#!/usr/bin/env bash
# Creates the starting state for ats-116-capstone-010.
#
# The corrected configuration is NOT applied here - producing it is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done

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

echo "[lab] Seeding OpenBao: KV version 2, the inventory secret, Kubernetes auth..."
bao_root secrets list -format=json | grep -q '"secret/"' || bao_root secrets enable -path=secret kv-v2
bao_root kv put secret/inventory/config \
  db_host=postgres.inventory.svc db_user=inventory api_key=initial-api-key >/dev/null
bao_root auth list -format=json | grep -q '"kubernetes/"' || bao_root auth enable kubernetes
bao_root write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc:443 >/dev/null
bao_root policy write inventory-reader - <<'POLICY'
# Read the inventory secrets, nothing else.
path "secret/data/inventory/*" {
  capabilities = ["read"]
}
POLICY
kubectl create namespace apicapstone --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "[lab] Creating the userpass user deployer and its policy..."
bao_root auth list -format=json | grep -q '"userpass/"' || bao_root auth enable userpass
bao_root policy write inventory-writer - <<'POLICY'
# Write and read the inventory secrets, and list their names.
path "secret/data/inventory/*" {
  capabilities = ["create", "read", "update"]
}
path "secret/metadata/inventory/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/inventory" {
  capabilities = ["list"]
}
POLICY
bao_root write auth/userpass/users/deployer password=deployer-password token_policies=inventory-writer >/dev/null
# An audit device, so a grader can see who wrote what.
bao_root audit list -format=json 2>/dev/null | grep -q '"file/"' || \
  bao_root audit enable file file_path=/openbao/logs/audit.log >/dev/null
echo "[lab] Creating the AppRole report and the report CronJob..."
bao_root kv put secret/inventory/api api_key=reporting-api-key >/dev/null
bao_root kv put secret/inventory/billing account=inventory-billing >/dev/null
bao_root policy write inventory-lister - <<'POLICY'
# Read the inventory secrets and list their names.
path "secret/data/inventory/*" {
  capabilities = ["read"]
}
path "secret/metadata/inventory" {
  capabilities = ["list"]
}
POLICY
bao_root auth list -format=json | grep -q '"approle/"' || bao_root auth enable approle
bao_root write auth/approle/role/report token_policies=inventory-lister token_ttl=10m >/dev/null
ROLE_ID="$(bao_root read -field=role_id auth/approle/role/report/role-id)"
SECRET_ID="$(bao_root write -f -field=secret_id auth/approle/role/report/secret-id)"
kubectl -n "apicapstone" create secret generic report-approle \
  --from-literal=role-id="$ROLE_ID" --from-literal=secret-id="$SECRET_ID" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$MANIFEST_DIR/app.yaml"
if kubectl -n apicapstone get deployment inventory >/dev/null 2>&1; then
  kubectl -n apicapstone rollout status deployment/inventory --timeout=180s || true
fi
echo "[lab] Starting state ready."
