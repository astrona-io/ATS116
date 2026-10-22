# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** OpenBao Proxy

## Scenario

The `inventory` app in the namespace `proxy-demo` was written to call OpenBao through a local proxy: its `nginx` configuration forwards `/config` to `http://127.0.0.1:8100/v1/secret/data/inventory/config`. Nobody added the proxy. The app answers `502`, and the service account `inventory-proxy` that the pod already runs as has no role in OpenBao.

```sh
kubectl -n clients exec deploy/tester -- curl -s -o /dev/null -w '%{http_code}\n' http://inventory.proxy-demo/config
```

## Your task

1. In OpenBao, create the Kubernetes auth role `inventory-proxy` for the service account `inventory-proxy` in the namespace `proxy-demo`, with the policy `inventory-reader` only.
2. Add OpenBao Proxy 2.7.1 (`quay.io/openbao/openbao:2.7.1`) as a sidecar container to the `inventory` Deployment. It must log in with the Kubernetes auth method and that role, add its auto-auth token to the app's requests, and listen on `127.0.0.1:8100` without TLS.
3. The app's `/config` must return the current `secret/inventory/config` through the proxy.

## Constraints

- Do not change the `app` container: same image, no command or arguments, same `nginx-conf`.
- No OpenBao token in the pod, the Deployment or any ConfigMap.
- The proxy must not be reachable from outside its pod, and the Service must not expose port 8100.
- Do not change the policy `inventory-reader`.

## Done when

- `http://inventory.proxy-demo/config` returns the secret with the current `api_key`.
- A request to the pod's address on port 8100 from another pod fails, and the Service has no port 8100.
- The role `inventory-proxy` is bound only to `inventory-proxy` in `proxy-demo` with `inventory-reader`.
- The app container is unchanged and no token is stored in the pod spec or its ConfigMaps.
