# Overview: Give Applications A Token-Free Path With OpenBao Proxy (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao, initializes and unseals it, and runs the `inventory` app with an OpenBao Proxy sidecar. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The secret `secret/inventory/config`, the policy `inventory-reader`, and the Kubernetes auth role `inventory-proxy` for the service account `inventory-proxy` in `proxy-demo`.
- The namespace **`proxy-demo`** with the Deployment `inventory`: a `proxy` container (OpenBao Proxy 2.7.1 on `127.0.0.1:8100`, configuration in the ConfigMap `proxy-config`) and an `app` container (`nginx:1.27-alpine`) that forwards `/config` to the proxy.
- A `tester` pod in the namespace `clients`, with `curl` and `jq`.

## Helpers

Start the port-forward in a second terminal first: `kubectl -n openbao port-forward svc/openbao 8200:8200`. Then paste these into each new terminal. `show_config` asks the app for its secret. `from_app` sends a request to the proxy from inside the app container. `proxy_log` prints the last lines of the proxy's log.

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
show_config() {
  kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config | jq '.data.data'
}
from_app() {
  kubectl -n proxy-demo exec deploy/inventory -c app -- wget -qO- "http://127.0.0.1:8100/v1/$1"
}
proxy_log() {
  kubectl -n proxy-demo logs deploy/inventory -c proxy | tail -n "${1:-20}"
}
```

Use them like this: `show_config`, `from_app secret/data/inventory/config`, `proxy_log 50`.

## Practice tasks

- Ask the proxy for `sys/health` and for `auth/token/lookup-self` with `from_app`. Which policies does the proxy's token have?
- Try `from_app secret/data/billing/config`. Which component refused it, and why?
- Change the listener to `0.0.0.0:8100`, restart the pod, and reach the proxy from the `tester` pod by the pod's address. Then put `127.0.0.1` back.
- Set `use_auto_auth_token = "force"` and send a request with a made-up `X-Vault-Token` header. Compare with `true`.
- Change the role's `bound_service_account_namespaces` to `default`, restart the pod and read `proxy_log`. Then put `proxy-demo` back.
- Add a `cache {}` stanza and clear the cache with `/proxy/v1/cache-clear` and the type `all`.
