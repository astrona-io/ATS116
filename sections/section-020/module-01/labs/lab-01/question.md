# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** OpenBao Agent

## Scenario

The `inventory` app in the namespace `agent-demo` reads its configuration from `/etc/inventory/config.env` and serves it at `/config`. An OpenBao Agent container in the same pod should write that file from `secret/inventory/config`. The team copied the agent configuration from another project, and the app has served nothing since.

Check it from the `tester` pod:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
```

## Your task

Fix the agent configuration in the ConfigMap `agent-config` so that:

1. The agent logs in with the Kubernetes auth role that exists for this app.
2. The app serves `/config` with three lines, `DB_HOST=`, `DB_USER=` and `API_KEY=`, holding the current values of `secret/inventory/config`.
3. A new version of `secret/inventory/config` reaches `/config` within about a minute, **without restarting the pod**.

## Constraints

- Do not put any OpenBao token into the pod: no environment variable, no ConfigMap entry and no `token_file` method.
- Do not change the Kubernetes auth role `inventory-agent` or the policy `inventory-reader`; they are correct.
- Do not change the `app` container or the ConfigMap `nginx-conf`.

## Done when

- `http://inventory.agent-demo/config` shows `db_host` and the current `api_key`.
- After a new `api_key` is written to OpenBao, the app shows it within 90 seconds, served by the same pod.
- No token is stored in the Deployment or its ConfigMaps, and the role is still bound only to `inventory-agent` in `agent-demo` with `inventory-reader`.
