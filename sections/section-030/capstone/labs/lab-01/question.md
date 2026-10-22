# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** OpenBao Proxy

## Scenario

The `inventory` app in the namespace `proxycapstone` has read its secret from OpenBao for a year. Its `nginx` configuration forwards `/config` straight to OpenBao and adds a header `X-Vault-Token` with a long-lived token that somebody created by hand. A security review found the token in the ConfigMap `nginx-conf`. The token works, which is the problem: anyone who can read that ConfigMap can read the inventory secrets until the token is revoked.

```sh
kubectl -n proxycapstone get configmap nginx-conf -o jsonpath='{.data.default\.conf}'
```

## Your task

Move the app to an OpenBao Proxy sidecar and get rid of the static token:

1. Give the pod its own service account `inventory-proxy`, and create the Kubernetes auth role `inventory-proxy` for it in `proxycapstone` with the policy `inventory-reader` only.
2. Add an OpenBao Proxy 2.7.1 sidecar that logs in with that role, adds its auto-auth token to the app's requests, and listens on `127.0.0.1:8100`.
3. Change `nginx-conf` so the app forwards `/config` to the proxy, with no token header.
4. Revoke the old long-lived token.

## Constraints

- Keep the `app` container's image (`nginx:1.27-alpine`) and its default command.
- No OpenBao token anywhere in the pod, the Deployment or its ConfigMaps.
- The proxy must not be reachable from outside its pod; the Service exposes only port 80.
- Do not change the policy `inventory-reader`.

## Done when

- `http://inventory.proxycapstone/config` returns the current secret through the proxy.
- The old long-lived token no longer exists.
- No token is stored in the Deployment or its ConfigMaps, and port 8100 is not reachable from another pod.
- The role `inventory-proxy` is bound only to `inventory-proxy` in `proxycapstone` with `inventory-reader`, and the app container is unchanged.
