# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** The Kubernetes agent injector

## Scenario

The `inventory` app in the namespace `inventory` already gets `secret/inventory/config` as `/vault/secrets/config.env` from the agent injector, and serves it at `/config`. A second client needs the secret `secret/inventory/api` as JSON at `/api`. The web server is set up to serve the file `/vault/secrets/api.json`, and the file does not exist, so `/api` answers `404`.

```sh
kubectl -n clients exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://inventory.inventory/api
```

## Your task

Add annotations to the pod template of the `inventory` Deployment so that the injector also writes `/vault/secrets/api.json` from `secret/inventory/api`. The file is valid JSON with these fields:

- `api_url`: the value of `api_url`, as a string,
- `api_token`: the value of `api_token`, as a string,
- `version`: the KV version of the secret that was rendered, as a JSON **number**.

A new version of `secret/inventory/api` must reach `/api` within about a minute, without replacing the pod.

## Constraints

- Keep the annotations of the first secret as they are. `/config` must keep working.
- Do not change the `app` container, `nginx-conf`, the ServiceAccount, the role `inventory` or the policy `inventory-reader`.
- No OpenBao token in the pod, the Deployment or any ConfigMap.

## Done when

- The running pod has `/vault/secrets/api.json` and `/vault/secrets/config.env`.
- `http://inventory.inventory/api` returns valid JSON with the current `api_url`, `api_token` and numeric `version`.
- A new `api_token` appears in `/api` within 90 seconds, served by the same pod as before the change was visible.
- `/config` still shows the current values of the first secret.
