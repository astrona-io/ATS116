# Summary

OpenBao Proxy gives an application a path to OpenBao that needs no token. The application sends plain HTTP API requests to the proxy, and the proxy forwards them with its own token, gained through auto-auth.

## What you learned

The proxy reads an HCL configuration with a `vault` stanza for the server address, an `auto_auth` stanza for its login, an `api_proxy` stanza, and a `listener`. With the `kubernetes` method it logs in with the pod's service account, and a Kubernetes auth role gives it a token with the role's policies. `use_auto_auth_token = true` adds that token only to requests that carry none; a request with its own `X-Vault-Token` is forwarded with that token. `"force"` replaces every caller's token with the proxy's. Requests through the proxy are raw API requests, so KV version 2 paths need `data/`.

Because the proxy lends its identity to anyone who reaches it, it belongs in the application's pod as a sidecar, with its listener on `127.0.0.1`. Containers in the pod share that address; nothing outside the pod can reach it, and the Service exposes only the application's port. Each application gets its own service account, its own role and its own proxy. Adding a proxy takes a service account, a role bound to exactly that account and namespace, a ConfigMap with the configuration, and a `proxy` container; the application container stays as it is.

A `cache` stanza makes the proxy keep new tokens and leased secrets created through it, and renew them. KV version 2 reads have no lease and are never cached. Revocations through the proxy evict their entries; revocations made directly on OpenBao do not, and `/proxy/v1/cache-clear` empties the cache by type. The key facts to remember are these:

- The application sends no token; the proxy adds its auto-auth token.
- Listener on `127.0.0.1`, proxy as a sidecar, port not in the Service.
- One service account, one role, one narrow policy per application.
- Caching helps logins and dynamic secrets, not KV reads.

<!-- astrona:playground:destroy -->
