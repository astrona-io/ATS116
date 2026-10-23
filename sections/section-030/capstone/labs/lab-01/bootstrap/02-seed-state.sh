#!/usr/bin/env bash
# Creates the starting state for ats-116-capstone-030.
#
# The corrected configuration is NOT applied here - producing it is the task.
set -euo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

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
kubectl create namespace proxycapstone --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "[lab] Creating the long-lived token the app uses today..."
STATIC="$(bao_root token create -orphan -policy=inventory-reader -period=768h -display-name=inventory-static -field=token)"
ACCESSOR="$(bao_root token lookup -format=json "$STATIC" | jq -r '.data.accessor')"
kubectl -n openbao create secret generic capstone-baseline --from-literal=static-accessor="$ACCESSOR" \
  --dry-run=client -o yaml | kubectl apply -f -
sed "s|@STATIC_TOKEN@|$STATIC|" "$MANIFEST_DIR/app.yaml" | kubectl apply -f -
if kubectl -n proxycapstone get deployment inventory >/dev/null 2>&1; then
  kubectl -n proxycapstone rollout status deployment/inventory --timeout=180s || true
fi
echo "[lab] Starting state ready."
