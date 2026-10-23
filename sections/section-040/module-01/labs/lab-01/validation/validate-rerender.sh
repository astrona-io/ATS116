#!/usr/bin/env bash
# PASS when a new KV version reaches the app within 90 seconds, with no restart.
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

POD_BEFORE="$(kubectl -n inventory get pods -l app=inventory -o jsonpath='{.items[0].metadata.name}')"
NEW_KEY="grader-$(date +%s)"
bao_root kv patch secret/inventory/config api_key="$NEW_KEY" >/dev/null
for _ in $(seq 1 30); do
  if app_get inventory /config | grep -q "$NEW_KEY"; then
    POD_AFTER="$(kubectl -n inventory get pods -l app=inventory -o jsonpath='{.items[0].metadata.name}')"
    if [ "$POD_BEFORE" != "$POD_AFTER" ]; then
      echo "FAIL: the new value arrived only because the pod was replaced."
      exit 1
    fi
    echo "PASS: the new api_key reached the app without a restart."
    exit 0
  fi
  sleep 3
done
echo "FAIL: the app still serves the old api_key 90 seconds after a new secret version."
exit 1
