#!/usr/bin/env bash
# OS prep for the "Render Secrets Into Files With OpenBao Agent" playground (`ats-116-playground-020-01`).
#
# Environment preparation only. There is no task and no grading. This script
# installs OpenBao initialized and unsealed (lab-only key and token in the
# Secret openbao-init), seeds it, and starts the module's workloads.
set -euo pipefail

HELM_VERSION="3.22.1"
OPENBAO_VERSION="2.7.1"
OPENBAO_CHART_VERSION="0.30.4"
OPENBAO_HOST="openbao.localtest.me"
INIT_MODE="${INIT_MODE:-unsealed}"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Pin the tools rather than accepting whatever is on the machine.
have_helm=""
command -v helm >/dev/null 2>&1 && have_helm=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//')
if [ "$have_helm" != "$HELM_VERSION" ]; then
  echo "[playground] Downloading Helm ${HELM_VERSION} (${OS}/${ARCH})..."
  curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
have_bao=""
command -v bao >/dev/null 2>&1 && have_bao=$(bao version 2>/dev/null | awk '{print $2}' | sed 's/^v//')
if [ "$have_bao" != "$OPENBAO_VERSION" ]; then
  echo "[playground] Downloading the bao CLI ${OPENBAO_VERSION} (${OS}/${ARCH})..."
  curl -fsSL "https://github.com/openbao/openbao/releases/download/v${OPENBAO_VERSION}/openbao_${OPENBAO_VERSION}_${OS}_${ARCH}.tar.gz" \
    | tar -xz -C "$WORK"
  install -m 0755 "$WORK/bao" "$BIN_DIR/bao"
fi
helm version --short
bao version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done

# One address for the reader's machine and the cluster: openbao.localtest.me
# resolves to 127.0.0.1 on the machine (reached through a port-forward), and
# this CoreDNS block sends the same name to the OpenBao Service in the cluster.
# The answer is rewritten back to the asked name: Go programs ignore DNS
# answers whose name differs from the question.
if ! kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -q "$OPENBAO_HOST"; then
  echo "[playground] Adding the CoreDNS rewrite for ${OPENBAO_HOST}..."
  COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
    | awk '/^[[:space:]]*kubernetes / && !done {
        print "    rewrite stop {"
        print "        name regex openbao\\.localtest\\.me openbao.openbao.svc.cluster.local"
        print "        answer name openbao\\.openbao\\.svc\\.cluster\\.local openbao.localtest.me"
        print "    }"
        done=1
      } {print}')"
  kubectl -n kube-system create configmap coredns --from-literal=Corefile="$COREFILE" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
fi

# lab-start.yaml is also listed under bootstrap.manifests in config.yaml, so it
# may already be applied. kubectl apply is idempotent.
kubectl apply -f "$MANIFEST_DIR/lab-start.yaml"
kubectl -n clients rollout status deployment/tester --timeout=300s

echo "[playground] Installing OpenBao (chart ${OPENBAO_CHART_VERSION})..."
helm repo add openbao https://openbao.github.io/openbao-helm >/dev/null 2>&1 || true
helm repo update openbao >/dev/null
VALUES_ARGS=(--values "$MANIFEST_DIR/openbao-values.yaml")
# Section 040 environments add the agent injector with pinned images.
[ -f "$MANIFEST_DIR/injector-values.yaml" ] && VALUES_ARGS+=(--values "$MANIFEST_DIR/injector-values.yaml")
# No --wait: a sealed OpenBao pod is never Ready, by design.
helm upgrade --install openbao openbao/openbao --version "$OPENBAO_CHART_VERSION" \
  --namespace openbao --create-namespace "${VALUES_ARGS[@]}"
for _ in $(seq 1 120); do
  [ "$(kubectl -n openbao get pod openbao-0 -o jsonpath='{.status.containerStatuses[0].started}' 2>/dev/null)" = "true" ] && break
  sleep 5
done

bao_in_pod() { kubectl -n openbao exec -i openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 bao "$@"; }

if [ "$INIT_MODE" = "unsealed" ]; then
  if ! kubectl -n openbao get secret openbao-init >/dev/null 2>&1; then
    echo "[playground] Initializing OpenBao with one lab-only unseal key..."
    INIT_JSON="$(bao_in_pod operator init -key-shares=1 -key-threshold=1 -format=json)"
    UNSEAL_KEY="$(printf '%s' "$INIT_JSON" | tr -d '\n ' | sed -n 's/.*"unseal_keys_b64":\["\([^"]*\)".*/\1/p')"
    ROOT_TOKEN="$(printf '%s' "$INIT_JSON" | tr -d '\n ' | sed -n 's/.*"root_token":"\([^"]*\)".*/\1/p')"
    kubectl -n openbao create secret generic openbao-init \
      --from-literal=unseal-key="$UNSEAL_KEY" --from-literal=root-token="$ROOT_TOKEN"
  fi
  UNSEAL_KEY="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.unseal-key}' | base64 -d)"
  bao_in_pod operator unseal "$UNSEAL_KEY" >/dev/null
  kubectl -n openbao wait --for=condition=Ready pod/openbao-0 --timeout=300s
fi

if kubectl -n openbao get deployment openbao-agent-injector >/dev/null 2>&1; then
  echo "[playground] Waiting for the agent injector..."
  kubectl -n openbao rollout status deployment/openbao-agent-injector --timeout=300s
fi

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

echo "[playground] Seeding OpenBao: KV version 2, the inventory secret, Kubernetes auth..."
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
kubectl create namespace agent-demo --dry-run=client -o yaml | kubectl apply -f - >/dev/null
bao_root write auth/kubernetes/role/inventory-agent bound_service_account_names=inventory-agent bound_service_account_namespaces=agent-demo token_policies=inventory-reader token_ttl=1h >/dev/null
kubectl apply -f "$MANIFEST_DIR/app.yaml"
if kubectl -n agent-demo get deployment inventory >/dev/null 2>&1; then
  kubectl -n agent-demo rollout status deployment/inventory --timeout=180s || true
fi

echo "[playground] Ready."
kubectl -n agent-demo get pods 2>/dev/null || true
echo "[playground] Start the port-forward in a second terminal before you use bao:"
echo "  kubectl -n openbao port-forward svc/openbao 8200:8200"
echo "  export BAO_ADDR=http://openbao.localtest.me:8200"
