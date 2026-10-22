# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** The Kubernetes agent injector

## Scenario

The `inventory` app in the namespace `injectcapstone` was moved to the agent injector last week. The Deployment carries every injector annotation, the role exists in OpenBao, and the team is sure the template is right. Still, the app has never served its configuration.

```sh
kubectl -n clients exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://inventory.injectcapstone/config
```

## Your task

Make the app in `injectcapstone` serve `/vault/secrets/config.env` with three lines, `DB_HOST=`, `DB_USER=` and `API_KEY=`, holding the current values of `secret/inventory/config`, and keep it up to date as the secret changes. There is more than one fault.

## Constraints

- Do not change the `app` container: same image `nginx:1.27-alpine`, no command or arguments.
- The pods keep running as the service account `inventory`. Fix the role in OpenBao to match it; do not bind the role to more than that one service account in `injectcapstone`.
- Keep the policy `inventory-reader` as it is, and put no OpenBao token into the pod or its ConfigMaps.

## Done when

- The running `inventory` pod is injected (`vault-agent-init` and `vault-agent`).
- `http://inventory.injectcapstone/config` shows `db_host` and the current `api_key`.
- A new `api_key` appears within 90 seconds, served by the same pod.
- The role `inventory` is bound only to `inventory` in `injectcapstone` with `inventory-reader`, and the app container is unchanged.
