# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** OpenBao Agent templates

## Scenario

The `inventory` app in the namespace `agent-demo` has an OpenBao Agent next to it. The agent already logs in and renders `/etc/inventory/config.env`, which the app serves at `/config`. A new client of the app wants the same data as JSON at `/config.json`, and the web server is already set up to serve the file `/etc/inventory/config.json`. No template writes that file yet.

Check what is served from the `tester` pod:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config.json
```

## Your task

Change the agent configuration in the ConfigMap `agent-config` so that:

1. The agent writes `/etc/inventory/config.json` from `secret/inventory/config`. The file is valid JSON with the string fields `db_host`, `db_user` and `api_key`, and the field `version`, a JSON **number** that holds the KV version of the secret that was rendered.
2. A new version of the secret reaches both `/config` and `/config.json` within about a minute, **without restarting the pod**.
3. A missing or misspelled field makes the template fail instead of writing an empty value.

## Constraints

- Keep the existing template for `/etc/inventory/config.env`.
- Do not put any OpenBao token into the pod: no environment variable, no ConfigMap entry and no `token_file` method.
- Do not change the `app` container, the ConfigMap `nginx-conf`, the role `inventory-agent` or the policy `inventory-reader`.

## Done when

- `http://inventory.agent-demo/config.json` returns valid JSON with the current `db_host`, `db_user`, `api_key` and the current numeric `version`.
- `http://inventory.agent-demo/config` still shows the current values.
- After a new `api_key` is written to OpenBao, `/config.json` shows it and the matching new `version` within 90 seconds, served by the same pod.
- No token is stored in the Deployment or its ConfigMaps.
