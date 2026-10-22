# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** The Kubernetes agent injector

## Scenario

The `inventory` app in the namespace `inventory` is an `nginx` server that serves `/vault/secrets/config.env` at `/config`. The platform team installed the OpenBao agent injector, and the app team wants their secrets delivered by it, without touching the app. So far the app answers `404`: nothing writes the file.

```sh
kubectl -n clients exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://inventory.inventory/config
```

## Your task

1. Create the Kubernetes auth role `inventory` in OpenBao for the service account `inventory` in the namespace `inventory`, with the policy `inventory-reader` only.
2. Annotate the `inventory` Deployment so the injector adds OpenBao Agent to its pods and renders `/vault/secrets/config.env` with three lines, from `secret/inventory/config`:

   ```
   DB_HOST=<db_host>
   DB_USER=<db_user>
   API_KEY=<api_key>
   ```

3. A new version of `secret/inventory/config` must reach `/config` within about a minute, without replacing the pod.

## Constraints

- Do not change the `app` container: same image `nginx:1.27-alpine`, no command or arguments.
- Do not change `nginx-conf`, the ServiceAccount or the policy `inventory-reader`.
- No OpenBao token in the pod, the Deployment or any ConfigMap.

## Done when

- The running `inventory` pod has the injected `vault-agent-init` and `vault-agent` containers.
- `http://inventory.inventory/config` shows `db_host` and the current `api_key`.
- A new `api_key` appears within 90 seconds, served by the same pod.
- The role `inventory` is bound only to `inventory` in `inventory` with `inventory-reader`, and the app container is unchanged.
