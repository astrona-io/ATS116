# Overview: Agent Templates In Depth (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao, initializes and unseals it, and runs the `inventory` app with a working OpenBao Agent next to it. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The secret `secret/inventory/config` with `db_host`, `db_user` and `api_key`, the policy `inventory-reader`, a PKI secrets engine at `pki/` with the role `web` (domain `inventory.example.com`, certificates up to one hour), the policies `pki-issuer` and `inventory-reader`, and the Kubernetes auth role `inventory-agent` for the service account `inventory-agent` in `agent-demo`.
- The namespace **`agent-demo`** with the Deployment `inventory`: an `agent` container (OpenBao Agent 2.7.1, configuration in the ConfigMap `agent-config`) and an `app` container (`nginx:1.27-alpine`) that serves the rendered file at `/config`, `/config.json` and `/tls.crt`. Only `/config` has a template at the start.
- A `tester` pod in the namespace `clients`, with `curl` and `jq`.

## Helpers

Start the port-forward in a second terminal first: `kubectl -n openbao port-forward svc/openbao 8200:8200`. Then paste these into each new terminal. `show_config` asks the app for its configuration. `agent_log` prints the last lines of the agent's log. `edit_agent` opens the agent configuration and restarts the pod after you save it.

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
show_config() {
  kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
}
agent_log() {
  kubectl -n agent-demo logs deploy/inventory -c agent | tail -n "${1:-20}"
}
edit_agent() {
  kubectl -n agent-demo edit configmap agent-config && \
    kubectl -n agent-demo rollout restart deployment/inventory && \
    kubectl -n agent-demo rollout status deployment/inventory
}
```

Use them like this: `show_config`, `agent_log 50`, `edit_agent`.

## Practice tasks

- Add a second `template` stanza that writes `/etc/inventory/config.json` with `toJSON`, and read it at `/config.json`.
- Add `error_on_missing_key = true` to a template, misspell a field and read `agent_log`.
- Use `{{ range $key, $value := .Data.data }}` to render every field of the secret. Add a field with `bao kv patch` and watch it appear.
- Change `left_delimiter` and `right_delimiter` to `[[` and `]]` in one template and render a line that contains `{{` as plain text.
- Set `static_secret_render_interval` to `5s`, patch the secret and time how long the file takes to change. Set it to `1m` and repeat.
- Add a `template` that renders the certificate with `pkiCert "pki/issue/web" "common_name=app.inventory.example.com" "ttl=2m"` to `/etc/inventory/tls.crt`, read `/tls.crt` and compare `serial_number` after the first TTL expires.
- Use `command = "touch /etc/inventory/rendered"` in a template and find the file with `kubectl exec`.
- Add `wait { min = "5s" max = "10s" }` to a template and patch the secret several times in a row. How many renders do you see in the log?
