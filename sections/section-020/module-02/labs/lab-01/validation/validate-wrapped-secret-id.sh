#!/usr/bin/env bash
# PASS when Secret nightly-approle holds the role ID and an unused wrapped secret ID for the role nightly.
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

ROLE_ID_SAVED="$(kubectl -n agent-demo get secret nightly-approle -o jsonpath='{.data.role-id}' 2>/dev/null | base64 -d)"
WRAP_TOKEN="$(kubectl -n agent-demo get secret nightly-approle -o jsonpath='{.data.wrapped-secret-id}' 2>/dev/null | base64 -d)"
if [ -z "$ROLE_ID_SAVED" ] || [ -z "$WRAP_TOKEN" ]; then
  echo "FAIL: Secret nightly-approle in agent-demo needs the keys role-id and wrapped-secret-id."
  exit 1
fi
ROLE_ID_REAL="$(bao_root read -field=role_id auth/approle/role/nightly/role-id 2>/dev/null || true)"
if [ "$ROLE_ID_SAVED" != "$ROLE_ID_REAL" ]; then
  echo "FAIL: the role-id in the Secret is not the role ID of the role nightly."
  exit 1
fi
INFO="$(openbao_api POST sys/wrapping/lookup "" "{\"token\":\"$WRAP_TOKEN\"}")"
PATH_SEEN="$(printf '%s' "$INFO" | jq -r '.data.creation_path // empty')"
TTL_SEEN="$(printf '%s' "$INFO" | jq -r '.data.creation_ttl // empty')"
if [ "$PATH_SEEN" != "auth/approle/role/nightly/secret-id" ]; then
  echo "FAIL: the wrapping token is unknown, already used, or wraps '$PATH_SEEN' instead of auth/approle/role/nightly/secret-id."
  exit 1
fi
if [ "$TTL_SEEN" != "300" ]; then
  echo "FAIL: the wrapping token has a TTL of '$TTL_SEEN' seconds, expected 300 (5m)."
  exit 1
fi
echo "PASS: the Secret holds the role ID and an unused 5 minute wrapped secret ID."
exit 0
