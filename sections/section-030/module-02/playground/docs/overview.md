# Overview: Listeners, TLS And Token Control In OpenBao Proxy (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao, initializes and unseals it, and runs the `inventory` app with an OpenBao Proxy sidecar. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The secret `secret/inventory/config`, the policy `inventory-reader`, and the Kubernetes auth role `inventory-proxy` for the service account `inventory-proxy` in `proxy-demo`.
- The namespace **`proxy-demo`** with the Deployment `inventory`: a `proxy` container (OpenBao Proxy 2.7.1 on `127.0.0.1:8100`, configuration in the ConfigMap `proxy-config`) and an `app` container (`nginx:1.27-alpine`) that forwards `/config` to the proxy. Two more paths exist: `/legacy` sends a made-up `X-Vault-Token` header on the way to the proxy, and `/whoami` shows the token the proxy used.
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

- Call `/legacy` and `/whoami` from the `tester` pod with `use_auto_auth_token = true`. Then set it to `"force"`, restart the pod and call both again.
- Set `use_auto_auth_token = false`, restart, and call `/config`. Which request needs a token now?
- Add a second `listener "unix"` with an `address` such as `/tmp/proxy.sock` and reach it with `wget` from the `app` container if your build of `wget` supports sockets, or read the log line that shows the listener started.
- Add `require_request_header = true` to the TCP listener and call `from_app` with and without `--header 'X-Vault-Request: true'`. Check what `/config` does and why.
- Change the `vault` address to a port where nothing listens, restart the pod and read `proxy_log`. Put it back.
- Start the proxy with `-log-level=debug` by adding it to the container `command`, read the log while you call `/config`, and remove it again.
