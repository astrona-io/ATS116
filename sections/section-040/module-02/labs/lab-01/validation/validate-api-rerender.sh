#!/usr/bin/env bash
# PASS when a new version of secret/inventory/api reaches /api within 90 seconds, in the same pod.
set -uo pipefail
HELM_VERSION="3.22.1"
HARBOR_URL="https://harbor.localtest.me:8443"
for dir in /usr/local/bin "$HOME/.local/bin"; do
  [ -d "$dir" ] && PATH="$dir:$PATH"
done
export PATH

ws() {
  # ws COMMAND...: runs a command in the workstation pod.
  kubectl -n workstation exec -i deploy/workstation -- "$@"
}
harbor_api() {
  # harbor_api METHOD PATH [JSON]: calls the Harbor REST API v2.0 as admin.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ws curl -sS -u admin:Harbor12345 -X "$method" \
      -H 'Content-Type: application/json' --data-binary @- "$HARBOR_URL/api/v2.0$path"
  else
    ws curl -sS -u admin:Harbor12345 -X "$method" "$HARBOR_URL/api/v2.0$path"
  fi
}
harbor_status() {
  # harbor_status METHOD PATH [JSON]: prints only the HTTP status code.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ws curl -s -o /dev/null -w '%{http_code}' -u admin:Harbor12345 -X "$method" \
      -H 'Content-Type: application/json' --data-binary @- "$HARBOR_URL/api/v2.0$path"
  else
    ws curl -s -o /dev/null -w '%{http_code}' -u admin:Harbor12345 -X "$method" "$HARBOR_URL/api/v2.0$path"
  fi
}
psql_on() {
  # psql_on DEPLOYMENT SQL: runs one SQL statement against the registry database.
  kubectl -n harbor-deps exec -i "deploy/$1" -- psql -U harbor -d registry -tAc "$2"
}
s3() {
  # s3 ARGS...: runs `aws s3 ARGS` in the s3-client pod.
  kubectl -n harbor-deps exec -i deploy/s3-client -- aws s3 "$@"
}
registry_login() {
  ws regctl registry login harbor.localtest.me:8443 -u admin -p Harbor12345 >/dev/null 2>&1
}
wait_for_harbor() {
  # Waits until /api/v2.0/health reports every component healthy.
  for _ in $(seq 1 120); do
    if [ "$(harbor_api GET /health 2>/dev/null | ws jq -r '.status' 2>/dev/null)" = "healthy" ]; then
      return 0
    fi
    sleep 5
  done
  return 1
}

POD_BEFORE="$(kubectl -n inventory get pods -l app=inventory --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
NEW="grader-$(date +%s)"
bao_root kv patch secret/inventory/api api_token="$NEW" >/dev/null
WANT_V="$(bao_root kv get -format=json secret/inventory/api | jq -r '.data.metadata.version')"
for _ in $(seq 1 30); do
  BODY="$(app_get inventory /api)"
  GOT="$(printf '%s' "$BODY" | jq -r '.api_token // empty' 2>/dev/null)"
  GOT_V="$(printf '%s' "$BODY" | jq -r '.version // empty' 2>/dev/null)"
  if [ "$GOT" = "$NEW" ] && [ "$GOT_V" = "$WANT_V" ]; then
    POD_AFTER="$(kubectl -n inventory get pods -l app=inventory --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
    if [ "$POD_BEFORE" != "$POD_AFTER" ]; then
      echo "FAIL: the new value arrived only because the pod was replaced."
      exit 1
    fi
    echo "PASS: /api followed the new secret version without replacing the pod."
    exit 0
  fi
  sleep 3
done
echo "FAIL: /api still shows the old api_token or version 90 seconds after a new secret version."
exit 1
