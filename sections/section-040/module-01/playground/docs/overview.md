# Overview: Deliver Secrets To Pods With The Agent Injector (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao with the agent injector, initializes and unseals OpenBao, and runs the `inventory` app with injection working. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.
- The **agent injector** `openbao-agent-injector` (image `hashicorp/vault-k8s:1.7.6`) in `openbao`, injecting the agent image `quay.io/openbao/openbao:2.7.1`.
- The secret `secret/inventory/config`, the policy `inventory-reader`, and the Kubernetes auth role `inventory` for the service account `inventory` in the namespace `inventory`.
- The namespace **`inventory`** with the Deployment `inventory` (`nginx:1.27-alpine`, annotated for injection) that serves `/vault/secrets/config.env` at `/config`.
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

- Add `vault.hashicorp.com/agent-pre-populate-only: "true"` to the pod template, then patch the secret. Does `/config` change?
- Add a second file: `agent-inject-secret-db.env` with a template that renders only `DB_HOST`, and serve it with a second `location` in `nginx-conf`.
- Move the annotations from the pod template to the Deployment's own metadata and run `pod_status` after the rollout.
- Change the role to bind the service account `default` and watch the new pod stay in `Init:0/1`. Read `init_log`, then put `inventory` back.
- Set `agent-inject-perms-config.env` to `"0400"` and check what `nginx`, which runs as another user, can still read.
- Scale the injector to zero, delete the app pod, and run `pod_status`. Then scale it back and delete the pod again.
