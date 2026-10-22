# Overview: Render Secrets Into Files With OpenBao Agent (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao, initializes and unseals it, and runs the `inventory` app with a working OpenBao Agent next to it. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The secret `secret/inventory/config` with `db_host`, `db_user` and `api_key`, the policy `inventory-reader`, and the Kubernetes auth role `inventory-agent` for the service account `inventory-agent` in `agent-demo`.
- The namespace **`agent-demo`** with the Deployment `inventory`: an `agent` container (OpenBao Agent 2.7.1, configuration in the ConfigMap `agent-config`) and an `app` container (`nginx:1.27-alpine`) that serves the rendered file at `/config`.
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

- Patch `api_key` with `bao kv patch` and call `show_config` every five seconds until it changes. Compare the delay with `static_secret_render_interval`.
- Change the role in `auto_auth` to a name that does not exist and read `agent_log`. Then put it back.
- Add `error_on_missing_key = true` to the template and break a field name. Compare the log and the file with and without it.
- Add a line `VERSION={{ .Data.metadata.version }}` to the template and watch it count up as you patch the secret.
- Use `range` to render every field of the secret without naming them.
- Remove `inventory-reader` from the role with `bao write auth/kubernetes/role/inventory-agent bound_service_account_names=inventory-agent bound_service_account_namespaces=agent-demo token_policies=default` and restart the pod. Which log line tells you why the file stays empty? Put the policy back the same way.
