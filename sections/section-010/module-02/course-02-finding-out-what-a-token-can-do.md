# Finding Out What A Token Can Do

A `403` answer says that the token may not do the request, but not why. The reason is always in the policies of the token. This part shows how to ask OpenBao what a token may do on a path, how to read the policies themselves, and how to tell a missing policy rule from a wrong path.

The commands below need the port-forward from a second terminal, `BAO_ADDR`, `ROOT_TOKEN` as in the previous part, and `DEPLOYER_TOKEN` from a userpass login as `deployer`.

## A failed request

Start from a real failure. The user `deployer` can write under `secret/inventory/`, but its policy has no rule for `secret/data/other/`. Try to read there:

<!-- astrona:playground:renew -->

```sh
curl -s -w '\nHTTP %{http_code}\n' -H "X-Vault-Token: $DEPLOYER_TOKEN" "$BAO_ADDR/v1/secret/data/other/config"
```

The answer is status `403` with the error `permission denied`. OpenBao gives the same answer when a rule is missing and when the token is bad, so that an attacker learns nothing about which paths exist. You need a second source of truth, and OpenBao offers two.

## Asking for capabilities

The endpoint `sys/capabilities-self` takes a list of paths and returns what the calling token may do on each one. A capability is one permission in a policy rule: `create`, `read`, `update`, `patch`, `delete`, `list`, `sudo` or `deny`. Ask about three paths:

```sh
curl -s -X POST -H "X-Vault-Token: $DEPLOYER_TOKEN" \
  --data '{"paths":["secret/data/inventory/config","secret/metadata/inventory","secret/data/other/config"]}' \
  "$BAO_ADDR/v1/sys/capabilities-self" | jq
```

Each path has its own list. For the first path the list holds `create`, `read` and `update`; for the second, `list`; and for the third, `deny`, which is what OpenBao reports when no rule matches. The endpoint `sys/capabilities` does the same for another token, which you pass in the body, and needs a token that may call it.

## Reading the policies

The capabilities tell you the result. The policy tells you the cause. Policies are objects under `sys/policies/acl`. List them with the `LIST` method and read one by name, using the root token:

```sh
curl -s -X LIST -H "X-Vault-Token: $ROOT_TOKEN" "$BAO_ADDR/v1/sys/policies/acl" | jq '.data.keys'
curl -s -H "X-Vault-Token: $ROOT_TOKEN" "$BAO_ADDR/v1/sys/policies/acl/inventory-writer" | jq -r '.data.policy'
```

The second command prints the policy text. A rule is a `path` with a list of `capabilities`. The path in a rule is the API path, so a KV version 2 rule must say `secret/data/inventory/*` for values and `secret/metadata/inventory/*` for lists and versions. A rule for `secret/inventory/*` matches neither, which is the most common cause of a surprising `403`.

A rule path can end in `*` to match any suffix, or contain `+` to match exactly one path segment. When several rules match, OpenBao uses the most specific one, and `deny` in any matching rule wins over everything else.

## Writing a policy through the API

A policy is written with a `PUT` or `POST` that carries the policy text in a `policy` field. The answer is status `204`, with no body:

```sh
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X PUT -H "X-Vault-Token: $ROOT_TOKEN" \
  --data '{"policy":"path \"secret/data/other/*\" { capabilities = [\"read\"] }"}' \
  "$BAO_ADDR/v1/sys/policies/acl/other-reader"
```

Policies attach to tokens when the token is made, so changing a policy changes what every existing token with that policy may do. Check that the policy exists, then remove it so the playground stays as it was:

```sh
curl -s -X DELETE -o /dev/null -w 'HTTP %{http_code}\n' -H "X-Vault-Token: $ROOT_TOKEN" "$BAO_ADDR/v1/sys/policies/acl/other-reader"
```

You can now turn a `403` into an answer: ask for the token's capabilities on the exact path, then read the rule that should have allowed it. The next question is how to tell a token problem from a server problem.

## Common pitfalls

> [!WARNING]
> - **Using the logical path in a rule.** For KV version 2, write `secret/data/...` and `secret/metadata/...`.
> - **Checking capabilities with the wrong token.** `capabilities-self` answers for the token that sends it.
> - **Judging a policy change before you repeat the request.** The server applies a changed policy on the next request, so send the request again first.
> - **Forgetting `list`.** Reading a secret and listing its parent are two capabilities on two paths.
