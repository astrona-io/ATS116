#!/usr/bin/env bash
# PASS when /config.json is valid JSON with db_host, db_user, api_key and the numeric KV version.
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

BODY="$(app_get agent-demo /config.json)"
if ! printf '%s' "$BODY" | jq -e . >/dev/null 2>&1; then
  echo "FAIL: /config.json is not valid JSON."
  exit 1
fi
SECRET="$(bao_root kv get -format=json secret/inventory/config)"
for field in db_host db_user api_key; do
  WANT="$(printf '%s' "$SECRET" | jq -r ".data.data.$field")"
  GOT="$(printf '%s' "$BODY" | jq -r ".$field // empty")"
  if [ "$WANT" != "$GOT" ]; then
    echo "FAIL: $field in /config.json is '$GOT', expected '$WANT'."
    exit 1
  fi
done
WANT_V="$(printf '%s' "$SECRET" | jq -r '.data.metadata.version')"
if ! printf '%s' "$BODY" | jq -e '.version | type == "number"' >/dev/null 2>&1; then
  echo "FAIL: version in /config.json is missing or is not a JSON number."
  exit 1
fi
GOT_V="$(printf '%s' "$BODY" | jq -r '.version')"
if [ "$WANT_V" != "$GOT_V" ]; then
  echo "FAIL: version in /config.json is $GOT_V, the secret is at version $WANT_V."
  exit 1
fi
echo "PASS: /config.json holds the three fields and the current version $GOT_V."
exit 0
