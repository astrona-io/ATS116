# Overview: Annotations In Depth (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao with the agent injector, initializes and unseals OpenBao, and runs the `inventory` app with injection working. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The **agent injector** `openbao-agent-injector` (image `hashicorp/vault-k8s:1.7.6`) in `openbao`, injecting the agent image `quay.io/openbao/openbao:2.7.1`.
- The secrets `secret/inventory/config` and `secret/inventory/api`, the policy `inventory-reader`, and the Kubernetes auth role `inventory` for the service account `inventory` in the namespace `inventory`.
- The namespace **`inventory`** with the Deployment `inventory` (`nginx:1.27-alpine`, annotated for injection) that serves `/vault/secrets/config.env` at `/config`. The web server also serves `/vault/secrets/api.json` at `/api`; no annotation writes that file at the start.
- A `tester` pod in the namespace `clients`, with `curl` and `jq`.

## Helpers

Start the port-forward in a second terminal first: `kubectl -n openbao port-forward svc/openbao 8200:8200`. Then paste these into each new terminal. `show_config` asks the app for its file. `pod_status` prints the injection status and the containers of the current pod. `init_log` prints the init container's log.

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
show_config() {
  kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/config
}
pod_status() {
  kubectl -n inventory get pods -l app=inventory \
    -o jsonpath='{range .items[*]}{.metadata.name}{"  status="}{.metadata.annotations.vault\.hashicorp\.com/agent-inject-status}{"  init="}{.spec.initContainers[*].name}{"  containers="}{.spec.containers[*].name}{"\n"}{end}'
}
init_log() {
  kubectl -n inventory logs "$(kubectl -n inventory get pods -l app=inventory -o jsonpath='{.items[0].metadata.name}')" -c vault-agent-init | tail -n "${1:-20}"
}
```

Use them like this: `show_config`, `pod_status`, `init_log 40`.

## Practice tasks

- Add the secret `secret/inventory/api` with `agent-inject-secret-api`, `agent-inject-file-api: api.json` and a JSON template, and read `/api`.
- Remove the template annotation of one secret and read the file. The default output is the whole response in Go's map notation.
- Set `agent-inject-perms-config.env` to `"0400"` and see whether `nginx` can still read it.
- Add `agent-inject-command-config.env: "touch /vault/secrets/reloaded"` and find the file in the pod after a secret change.
- Set `agent-requests-cpu`, `agent-limits-cpu`, `agent-requests-mem` and `agent-limits-mem` on the pod template and read the resources of the injected containers with `kubectl get pod -o yaml`.
- Set `agent-init-first: "true"` and compare the order of the init containers.
- Set `agent-inject-token: "true"` and look for the token file in the pod. Then remove the annotation.
- Set `vault.hashicorp.com/log-level: "debug"` and read the sidecar log while you change the secret.
