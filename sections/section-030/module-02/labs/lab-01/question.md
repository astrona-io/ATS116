# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** OpenBao Proxy

## Scenario

The `inventory` app in the namespace `proxy-demo` runs with an OpenBao Proxy sidecar that is logged in and healthy. The app's `nginx` configuration forwards `/config` to the proxy, but an older version of the app also sent a token of its own in the `X-Vault-Token` header, and the header is still in the configuration. That token is no longer valid, so the app gets an error from OpenBao and `/config` returns no secret.

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config
```

## Your task

Change the proxy configuration so that `/config` returns the current `secret/inventory/config`, even though the app sends a token that is not valid. The proxy must always use its own auto-auth token.

## Constraints

- Do not change the ConfigMap `nginx-conf` or the `app` container. The old header stays where it is.
- No OpenBao token in the pod, the Deployment or the proxy configuration.
- The proxy must stay reachable only from inside its pod, and the Service must not expose port 8100.
- Do not change the Kubernetes auth role `inventory-proxy` or the policy `inventory-reader`.

## Done when

- `http://inventory.proxy-demo/config` returns the secret with the current `api_key`.
- A request to the proxy from the `app` container with any made-up `X-Vault-Token` is answered with the proxy's own identity.
- The listener is still bound to `127.0.0.1` and the role is unchanged.
