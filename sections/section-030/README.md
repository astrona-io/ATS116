# Section 030: OpenBao Proxy And Caching

Some applications already know how to call OpenBao's HTTP API: they read a secret by sending a request to `/v1/...`. What they should not do is hold a token. OpenBao Proxy fills that gap. It runs next to the application, logs in on its own, and forwards the application's requests to OpenBao with its own token attached. The application calls the proxy without any token at all.

This section runs the proxy as a sidecar container that only its own pod can reach, because a proxy that adds a token to every request must never be reachable from anywhere else.

## What you will learn

- The `bao proxy` configuration: `vault`, `auto_auth`, `api_proxy` and `listener`.
- `use_auto_auth_token`: when the proxy adds its token, when it keeps the caller's token, and what `force` changes.
- Why the listener binds to `127.0.0.1` and why the proxy runs in the application's pod.
- What the proxy caches: new tokens and leased secrets created through it, and their renewals.
- Clearing the cache with `/proxy/v1/cache-clear`, and when a cached entry goes stale.

## The learning path

The module starts at its landing page, which also launches the playground. The playground runs the `inventory` app in the namespace `proxy-demo` with an OpenBao Proxy sidecar.

### 1. Give Applications A Token-Free Path With OpenBao Proxy

1. The API Proxy And The Auto-Auth Token
2. Running The Proxy Next To The Application, followed by the lab **Serve Secrets To An App Through An OpenBao Proxy Sidecar**
3. Caching Tokens And Leases
4. Summary

## Section capstone: Move An App From A Static Token To OpenBao Proxy

The capstone is one graded scenario that combines the whole module. The `inventory` app in the namespace `proxycapstone` reads its secret with a long-lived token written into its configuration. Move it to an OpenBao Proxy sidecar, scope the proxy's role to what the app reads, and revoke the old token, without changing the app's image or command. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-116-capstone-030
```
