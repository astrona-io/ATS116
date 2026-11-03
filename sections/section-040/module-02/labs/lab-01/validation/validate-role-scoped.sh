#!/usr/bin/env bash
# PASS when the Kubernetes auth role inventory is bound to inventory in inventory with only inventory-reader.
set -uo pipefail
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

ROLE="$(bao_root read -format=json auth/kubernetes/role/inventory 2>/dev/null || true)"
if [ -z "$ROLE" ]; then
  echo "FAIL: the Kubernetes auth role inventory does not exist."
  exit 1
fi
NAMES="$(printf '%s' "$ROLE" | jq -r '.data.bound_service_account_names | join(",")')"
NAMESPACES="$(printf '%s' "$ROLE" | jq -r '.data.bound_service_account_namespaces | join(",")')"
POLICIES="$(printf '%s' "$ROLE" | jq -r '.data.token_policies | join(",")')"
if [ "$NAMES" != "inventory" ] || [ "$NAMESPACES" != "inventory" ]; then
  echo "FAIL: role inventory is bound to service accounts '$NAMES' in namespaces '$NAMESPACES', not inventory in inventory."
  exit 1
fi
if [ "$POLICIES" != "inventory-reader" ]; then
  echo "FAIL: role inventory grants policies '$POLICIES', expected only inventory-reader."
  exit 1
fi
if bao_root policy read inventory-reader | grep -qE '"\*"|sudo'; then
  echo "FAIL: policy inventory-reader was widened with a wildcard capability or sudo."
  exit 1
fi
echo "PASS: role inventory is scoped to inventory in inventory with inventory-reader."
exit 0
