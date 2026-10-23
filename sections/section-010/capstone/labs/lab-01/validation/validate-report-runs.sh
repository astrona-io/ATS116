#!/usr/bin/env bash
# PASS when a Job from the inventory-report CronJob completes and reports every key.
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

JOB="grader-$(date +%s)"
kubectl -n apicapstone create job "$JOB" --from=cronjob/inventory-report >/dev/null
if ! kubectl -n apicapstone wait --for=condition=complete "job/$JOB" --timeout=120s >/dev/null 2>&1; then
  echo "FAIL: Job $JOB did not complete. Its log:"
  kubectl -n apicapstone logs "job/$JOB" 2>/dev/null | tail -20
  exit 1
fi
LOG="$(kubectl -n apicapstone logs "job/$JOB")"
kubectl -n apicapstone delete job "$JOB" --wait=false >/dev/null 2>&1 || true
for key in api billing config; do
  if ! printf '%s\n' "$LOG" | grep -q "^$key: {"; then
    echo "FAIL: the report has no fields for '$key'. Its output:"
    printf '%s\n' "$LOG"
    exit 1
  fi
done
printf '%s\n' "$LOG" | grep -q "REPORT OK" || { echo "FAIL: the report did not finish."; exit 1; }
echo "PASS: the report lists api, billing and config with their fields."
exit 0
