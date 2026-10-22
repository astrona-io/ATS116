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

ACCESSOR="$(kubectl -n openbao get secret capstone-baseline -o jsonpath='{.data.static-accessor}' | base64 -d)"
bao_root write auth/kubernetes/role/inventory-proxy bound_service_account_names=inventory-proxy bound_service_account_namespaces=proxycapstone token_policies=inventory-reader token_ttl=1h >/dev/null
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inventory-proxy
  namespace: proxycapstone
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-config
  namespace: proxycapstone
data:
  proxy.hcl: |
    vault {
      address = "http://openbao.openbao.svc:8200"
    }

    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "inventory-proxy"
        }
      }
    }

    api_proxy {
      use_auto_auth_token = true
    }

    # Only containers in this pod can reach the proxy.
    listener "tcp" {
      address     = "127.0.0.1:8100"
      tls_disable = true
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
  namespace: proxycapstone
data:
  default.conf: |
    server {
      listen 80;
      location = /config {
        proxy_pass http://127.0.0.1:8100/v1/secret/data/inventory/config;
      }
      location = /healthz {
        return 200 "ok";
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: proxycapstone
  labels:
    app: inventory
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
    spec:
      serviceAccountName: inventory-proxy
      containers:
        - name: proxy
          image: quay.io/openbao/openbao:2.7.1
          command: ["bao", "proxy", "-config=/etc/openbao-proxy/proxy.hcl"]
          volumeMounts:
            - name: proxy-config
              mountPath: /etc/openbao-proxy
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d
      volumes:
        - name: nginx-conf
          configMap:
            name: nginx-conf
        - name: proxy-config
          configMap:
            name: proxy-config
YAML
kubectl -n proxycapstone rollout status deployment/inventory --timeout=180s
bao_root token revoke -accessor "$ACCESSOR" >/dev/null
