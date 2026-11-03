#!/usr/bin/env bash
# PASS when the AppRole nightly has the right policy, secret ID limits and token TTL.
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

ROLE="$(openbao_api GET auth/approle/role/nightly "$(root_token)")"
POLICIES="$(printf '%s' "$ROLE" | jq -r '.data.token_policies // empty | sort | join(",")')"
SECRET_TTL="$(printf '%s' "$ROLE" | jq -r '.data.secret_id_ttl // empty')"
SECRET_USES="$(printf '%s' "$ROLE" | jq -r '.data.secret_id_num_uses // empty')"
TOKEN_TTL="$(printf '%s' "$ROLE" | jq -r '.data.token_ttl // empty')"
if [ -z "$POLICIES" ]; then
  echo "FAIL: the AppRole nightly does not exist."
  exit 1
fi
if [ "$POLICIES" != "inventory-reader" ]; then
  echo "FAIL: the role has the policies '$POLICIES', expected only inventory-reader."
  exit 1
fi
if [ "$SECRET_TTL" != "600" ] || [ "$SECRET_USES" != "1" ]; then
  echo "FAIL: secret_id_ttl is '$SECRET_TTL' (expected 600) and secret_id_num_uses is '$SECRET_USES' (expected 1)."
  exit 1
fi
if [ "$TOKEN_TTL" != "1200" ]; then
  echo "FAIL: token_ttl is '$TOKEN_TTL' seconds, expected 1200 (20m)."
  exit 1
fi
echo "PASS: the role nightly has inventory-reader, a 10 minute one-use secret ID and a 20 minute token."
exit 0
