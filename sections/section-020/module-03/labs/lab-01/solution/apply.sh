#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this. Taken from solution.md - if one changes, change the other.
set -euo pipefail

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

kubectl -n agent-demo get configmap agent-config -o jsonpath='{.data.agent\.hcl}' > /tmp/agent.hcl
python3 - <<'PY'
p = "/tmp/agent.hcl"
s = open(p).read()
s = s.rstrip("\n") + """

template_config {
  static_secret_render_interval = "15s"
}

template {
  destination          = "/etc/inventory/config.json"
  error_on_missing_key = true
  contents             = <<EOT
{{ with secret "secret/data/inventory/config" }}{
  "db_host": {{ .Data.data.db_host | toJSON }},
  "db_user": {{ .Data.data.db_user | toJSON }},
  "api_key": {{ .Data.data.api_key | toJSON }},
  "version": {{ .Data.metadata.version }}
}{{ end }}
EOT
}
"""
open(p, "w").write(s)
PY
kubectl -n agent-demo create configmap agent-config --from-file=agent.hcl=/tmp/agent.hcl --dry-run=client -o yaml | kubectl apply -f -
kubectl -n agent-demo rollout restart deployment/inventory
kubectl -n agent-demo rollout status deployment/inventory --timeout=180s
