# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** OpenBao Agent

## Scenario

The batch team in the namespace `agentcapstone` runs the `inventory` app with an OpenBao Agent next to it, like every other team. Their pods cannot use the Kubernetes auth method, so the agent logs in with the AppRole `inventory-batch`. The role ID and secret ID are in the Kubernetes Secret `inventory-approle` and are mounted into the agent at `/etc/approle`. The app has never served its configuration, and nobody knows why.

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agentcapstone/config
```

## Your task

Make the app in `agentcapstone` serve its configuration from `secret/inventory/config`, and keep it fresh:

1. The agent must log in with the AppRole `inventory-batch`, using the role ID and secret ID files from the Secret `inventory-approle`.
2. The app must serve `DB_HOST=`, `DB_USER=` and `API_KEY=` with the current values.
3. A new version of the secret must reach the app within about a minute, without a pod restart.

## Constraints

- No OpenBao token in the pod, the Deployment or any ConfigMap. The AppRole files are the only credentials.
- The policy `batch-reader` must allow `read` on exactly `secret/data/inventory/config`. No wildcard paths such as `secret/data/*`, no `*` capabilities and no `sudo`.
- Do not change the AppRole `inventory-batch` itself, the Secret `inventory-approle`, or the `app` container.

## Done when

- `http://inventory.agentcapstone/config` shows `db_host` and the current `api_key`.
- A new `api_key` written to OpenBao shows up within 90 seconds, served by the same pod.
- `batch-reader` has a rule for `secret/data/inventory/config` and nothing wider; the AppRole still grants `batch-reader`.
