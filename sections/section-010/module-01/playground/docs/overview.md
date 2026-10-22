# Overview: Talk To OpenBao Over HTTP (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs OpenBao, initializes and unseals it, creates a few secrets and identities, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the `bao` command-line tool on your PATH. The lab-only unseal key and root token are in the Kubernetes Secret `openbao-init`; a real installation never keeps them there.
- A KV version 2 secrets engine at `secret/` with three secrets: `secret/inventory/config`, `secret/inventory/api` and `secret/inventory/billing`.
- The userpass user **`deployer`** (password `deployer-password`, lab-only) with the policy `inventory-writer`: write and read under `secret/inventory/`, and list it.
- The AppRole **`report`** with the policy `inventory-lister`: read under `secret/inventory/`, and list it.
- A file audit device that writes every request to `/openbao/logs/audit.log` inside the `openbao-0` pod.
- A `tester` pod in the namespace `clients`, with `curl` and `jq`.

## Helpers

Start the port-forward in a second terminal first: `kubectl -n openbao port-forward svc/openbao 8200:8200`. Then paste these into each new terminal. `root_login` loads the lab-only root token. `deployer_login` logs in as `deployer` and keeps the token in `DEPLOYER_TOKEN`. `openbao_get` sends an authenticated `GET` with the token you pass first.

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
root_login() {
  export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
}
deployer_login() {
  DEPLOYER_TOKEN="$(curl -s -X POST --data '{"password":"deployer-password"}' \
    "$BAO_ADDR/v1/auth/userpass/login/deployer" | jq -r '.auth.client_token')"
}
openbao_get() {
  curl -s -H "X-Vault-Token: $1" "$BAO_ADDR/v1/$2" | jq
}
```

Use them like this: `root_login`, `deployer_login`, `openbao_get "$DEPLOYER_TOKEN" secret/data/inventory/config`.

## Practice tasks

- Read `secret/inventory/config` with `curl`, then with `bao kv get`, and compare the two answers field by field.
- Write `secret/inventory/notes` three times as `deployer`, then read version 1 with `?version=1` on the `data/` path.
- List `secret/metadata/inventory` with `-X LIST`, with `?list=true`, and with a plain `GET`. Explain the third answer.
- Log in as the AppRole `report` and try every operation of `inventory-writer`. Write down which status code each one returns.
- Wrap a read for one minute, wait two minutes, and try to look the wrapping token up.
- Read the last lines of the audit log with `kubectl -n openbao exec openbao-0 -- tail -n 3 /openbao/logs/audit.log` and find your requests by their `path` and `display_name`.
