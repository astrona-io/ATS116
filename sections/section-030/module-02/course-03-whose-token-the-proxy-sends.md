# Whose Token The Proxy Sends

The proxy has its own token from auto-auth. A request may also carry a token of its own, in the `X-Vault-Token` header. The `use_auto_auth_token` setting decides which one OpenBao sees. A wrong choice shows up as either a request that is refused when it should work, or a caller who gets access it should not have.

## The three values

```hcl
api_proxy {
  use_auto_auth_token = true
}
```

| Value | What the proxy does |
| --- | --- |
| `false` (default) | Never adds its own token. A request without a token reaches OpenBao without one and is refused. |
| `true` | Adds its token when the request carries none. A request with a token is forwarded with that token. |
| `"force"` | Always replaces the request's token with its own. A request with a made-up token is sent with the proxy's token. |

`"force"` is a string. `true` and `false` are not.

## What each value is good for

`true` suits an application that sometimes brings its own token, for example a job that has been given a short-lived token for a special task, while the other requests use the proxy's. `"force"` suits an application that should never use any other identity: a legacy client that still sends an old token, or a library that always adds a token header. It also removes the risk that a client with a token for more than it should read more than the proxy's role allows through this path.

With `true`, a stale or invalid token in a request is not repaired. The proxy forwards it, and OpenBao answers `403 permission denied`. This is the usual cause of "the proxy works from my shell but not from the app".

## Seeing which token was used

Ask OpenBao who the token is, through the proxy. The `/whoami` path of the playground sends the lookup. From the `tester` pod:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/whoami | jq '.data | {display_name, policies}'
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/legacy | jq .
```

`/whoami` shows the proxy's own token, with the policies `default` and `inventory-reader`. `/legacy` sends a made-up token header. With `true`, it is refused. With `"force"`, it returns the secret.

## Choosing

Use `"force"` for an application that must use the proxy's identity only. Use `true` when callers may bring a more specific token. Use `false` only when you want the proxy as a pure forwarder, with caching and renewal, and every caller already has a token.

## Try it

1. Call `/legacy` from the `tester` pod and read the answer. It is an error from OpenBao.
2. Set `use_auto_auth_token = "force"` in the ConfigMap `proxy-config` and restart the pod.
3. Call `/legacy` again. It now returns the secret.
4. Set the value to `false`, restart, and call `/config`. It is refused. Put `true` back and restart.

## Common pitfalls

> [!WARNING]
> - **Writing `use_auto_auth_token = force` without quotes.** It must be the string `"force"`.
> - **Using `true` with a client that sends a token that is stale or wrong.** The stale token wins.
> - **Using `"force"` and forgetting that every caller now has the proxy's access.** Keep the listener closed.
> - **Setting `false` and expecting a token to appear.** With `false` the proxy adds nothing.

## Your mission: Make The Proxy Use Its Own Token

You can now explain the three values and see which token a request used. The graded lab gives you an `inventory` app that sends an old token in every request and gets refused, and asks you to change the proxy, not the app, so the app works again.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-030-02
astrona start ats-116-playground-030-02
```
