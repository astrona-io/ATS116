# Response Wrapping And Request Headers

Sometimes one party must hand a secret to another: a deployment pipeline gives a new service its AppRole secret ID, or an administrator gives a colleague a password. If the secret travels in a chat message or a log line, anyone who sees that message has it, and nobody notices. Response wrapping solves this. OpenBao keeps the real answer and hands out a single-use token instead, so the receiver can tell whether someone else already used it.

The commands below need the port-forward from the second terminal, `BAO_ADDR` set to `http://openbao.localtest.me:8200`, and `DEPLOYER_TOKEN` from a userpass login as `deployer` (password `deployer-password`).

## Asking for a wrapped response

Response wrapping means OpenBao stores a response in a single-use location (the cubbyhole of a new token) and returns that new token, the wrapping token, instead of the response. You ask for it with the request header `X-Vault-Wrap-TTL`, which also sets how long the wrapping token lives. Read the inventory notes again, this time wrapped for five minutes:

<!-- astrona:playground:renew -->

```sh
WRAPPED="$(curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" -H "X-Vault-Wrap-TTL: 5m" \
  "$BAO_ADDR/v1/secret/data/inventory/notes")"
printf '%s' "$WRAPPED" | jq '{data, wrap_info}'
```

`data` is now `null`, and `wrap_info` holds the wrapping token in `token`, its `ttl` in seconds (`300`), and `creation_path`, the path whose answer it wraps. The secret's values are not in this response at all; they wait inside OpenBao.

## Checking a wrapping token without using it

The receiver should check a wrapping token before using it. The lookup endpoint shows where the token came from without opening it, and it needs no token of its own:

```sh
WRAP_TOKEN="$(printf '%s' "$WRAPPED" | jq -r '.wrap_info.token')"
curl -s -X POST --data "{\"token\":\"$WRAP_TOKEN\"}" "$BAO_ADDR/v1/sys/wrapping/lookup" | jq '.data'
```

`creation_path` should be the path the receiver expects, here `secret/data/inventory/notes`. If it names another path, someone swapped the token. `creation_ttl` is the lifetime the sender asked for. Looking a token up does not use it.

## Unwrapping, once

Unwrapping gives the original response back, and it works exactly once. Send the wrapping token as the request's token to `sys/wrapping/unwrap`:

```sh
curl -s -X POST -H "X-Vault-Token: $WRAP_TOKEN" "$BAO_ADDR/v1/sys/wrapping/unwrap" | jq '.data.data'
```

The fields of the notes come back, exactly as an unwrapped read would show them. Now try the same request a second time:

```sh
curl -s -w '\nHTTP %{http_code}\n' -X POST -H "X-Vault-Token: $WRAP_TOKEN" "$BAO_ADDR/v1/sys/wrapping/unwrap"
```

This time OpenBao answers with an error: the wrapping token is no longer valid. That is the security property. If the intended receiver gets this error on its first try, someone else unwrapped the secret first, and the sender must treat the secret as leaked and replace it.

## Other request headers

A few more request headers change how OpenBao handles a request. You will meet them in tools and in server configurations:

| Header | What it does |
| --- | --- |
| `X-Vault-Token` | Carries the token (or `Authorization: Bearer <token>`) |
| `X-Vault-Wrap-TTL` | Wraps the response; the value is a duration such as `5m` or a number of seconds |
| `X-Vault-Request` | Marks the request as coming from an OpenBao client. A listener with `require_request_header` refuses requests without it, which blocks some browser-based attacks |
| `X-Vault-Namespace` | Sends the request to an OpenBao namespace instead of the root namespace |

The `bao` CLI sets `X-Vault-Request` on every request for you. When you write your own client, set it too if your server requires it.

You can now hand over a secret as a wrapping token, check where a wrapping token came from, and tell from a failed unwrap that someone else was first. With login, read, write, list and wrapping, you have every request a client needs; the next step is to do them for a real handover.

## Common pitfalls

> [!WARNING]
> - **Unwrapping to "check" a token.** Unwrapping uses it up. Check it with `sys/wrapping/lookup` instead.
> - **Ignoring a failed first unwrap.** It means someone else used the token. Replace the secret; do not just ask for a new wrapping token.
> - **Choosing a long wrapping TTL "to be safe".** A long TTL gives an attacker more time. Use the shortest time the receiver needs.
> - **Wrapping with the wrong token.** The wrapping token wraps whatever the request returned. A `403` wrapped is still a `403` for the receiver.

## Your mission: Hand Over A Secret With A Wrapped Response

You can now log in over HTTP, write a KV version 2 secret, and hand it over as a single-use wrapping token. The graded lab asks you to do this as the user `deployer`, not as root, and to leave the unused wrapping token in a Kubernetes Secret for the receiver.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-010-01
astrona start ats-116-playground-010-01
```
