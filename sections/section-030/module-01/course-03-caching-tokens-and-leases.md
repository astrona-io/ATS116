# Caching Tokens And Leases

Every request through the proxy goes to OpenBao, and that is fine for a few reads a minute. An application that logs in or asks for a fresh database credential on every request is different: it creates a new token or lease each time, and each one stays alive in OpenBao until it expires. OpenBao Proxy can cache those responses, hand the same one back to repeated requests, and renew it for as long as it is in use. This part shows what the cache keeps, what it does not keep, and how to empty it.

The commands below need the playground's `inventory` pod in `proxy-demo`.

## What the proxy caches

The cache stores responses that create something with a lifetime. The proxy caches a response in two cases:

1. **New tokens.** A login or a token-creation request sent through the proxy. The proxy caches the response only if the parent token is one the proxy already manages, or if the new token is an orphan.
2. **Leased secrets.** A dynamic secret, such as a database credential, requested through the proxy with a token the proxy manages.

The proxy then renews those tokens and leases itself, using OpenBao's renewal API, until they reach their maximum lifetime. A KV version 2 read is neither: it creates no token and has no lease, so every KV read through the proxy still reaches OpenBao. The secret `secret/inventory/config` in this playground is never cached.

The proxy recognises a repeated request by a hash of the whole request: method, path, headers and body. Two requests that differ in any byte, even the order of their JSON fields, are two cache entries. Applications that build their requests the same way every time benefit most.

## Turning the cache on

Caching is off unless the configuration has a `cache` stanza. An empty stanza is enough. Add it to the proxy's configuration and restart the pod:

<!-- astrona:playground:renew -->

```sh
kubectl -n proxy-demo edit configmap proxy-config
kubectl -n proxy-demo rollout restart deployment/inventory
kubectl -n proxy-demo rollout status deployment/inventory
```

In the editor, add these lines to `proxy.hcl`, next to the `api_proxy` stanza, then save:

```hcl
cache {
}
```

Check that the proxy started with the new configuration and still forwards requests:

```sh
kubectl -n proxy-demo logs deploy/inventory -c proxy | tail -n 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config | jq '.data.data.db_host'
```

The application still gets its secret. With the cache on, the proxy would now also keep any token or lease created through it.

## Clearing the cache

A cached entry can go stale. If someone revokes a token or a lease directly on OpenBao, not through the proxy, the proxy does not know and keeps handing out the cached response. Revocations sent through the proxy are seen, and the proxy evicts the matching entries itself. For the other cases, the proxy offers an endpoint on its own listener, `/proxy/v1/cache-clear`. Clear the whole cache from inside the pod:

```sh
kubectl -n proxy-demo exec deploy/inventory -c app -- \
  wget -qO- --post-data '{"type":"all"}' http://127.0.0.1:8100/proxy/v1/cache-clear
```

The proxy answers with status `200`. Instead of `all`, `type` can be `request_path`, `lease`, `token` or `token_accessor`, with `value` holding the exact value or a prefix, to evict only some entries. The endpoint exists even when caching is off; then it does nothing and still answers `200`.

The cache lives in memory. When the proxy stops, it forgets every entry and stops renewing; the tokens and leases are not revoked, they simply expire on their own schedule. A `persist` block inside `cache` can write the cache to a file and restore it after a restart, but only the `kubernetes` type exists, and it is meant for proxies in Kubernetes that restart often.

You now know that the proxy caches new tokens and leased secrets, renews them, keeps nothing for KV reads, and can be told to forget. With the API proxy, the sidecar pattern and the cache, you have every piece of OpenBao Proxy.

## Common pitfalls

> [!WARNING]
> - **Expecting KV reads to be cached.** They have no lease, so they always reach OpenBao. Caching helps logins and dynamic secrets.
> - **Revoking directly on OpenBao and trusting the cache.** The proxy keeps the old entry. Revoke through the proxy, or clear the cache.
> - **Building requests differently each time.** A different header or field order is a different cache entry.
> - **Thinking a stopped proxy revokes its secrets.** It only stops renewing them; they live until their TTL runs out.
