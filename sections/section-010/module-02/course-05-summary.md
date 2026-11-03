# Summary

A token is an object with a lifetime, a use limit, a type and a list of policies, and OpenBao lets any client read these facts. Most `permission denied` errors come from one of them, so reading the token first saves a long search.

## What you learned

`auth/token/lookup-self` shows the policies, the time left and the uses left of a token. `renew-self` extends a token, up to the maximum TTL. `auth/token/create` makes a child token with its own lifetime, use limit and a subset of the parent's policies, and a revoked parent takes its children with it. Batch tokens are cheap and cannot be renewed, periodic tokens renew without a maximum, and orphan tokens have no parent.

To find out why a request fails, ask for the token's capabilities on the exact path with `sys/capabilities-self`, and read the policy under `sys/policies/acl`. KV version 2 rules must name `data/` and `metadata/` paths. A path with no matching rule reports `deny`.

The server reports its own state at endpoints that need no token. `sys/health` answers `200`, `429`, `501` or `503` for active, standby, uninitialized and sealed. Error status codes separate a bad request, a token or policy problem, a missing path and a server that is not ready. Retry `5xx` and `429`, not `4xx`.

The `bao` command is an HTTP client. The flag `-output-curl-string` prints the request behind a command, `-format=json` and `-field` make output usable in scripts, and `bao path-help` lists the fields of a path. The key facts to remember are these:

- `lookup-self`, `renew-self`, `revoke-self` work with the `default` policy.
- A child token can only have policies its parent has.
- `sys/capabilities-self` turns a `403` into a concrete missing capability.
- `sys/health`: `200` active, `429` standby, `501` uninitialized, `503` sealed.

<!-- astrona:playground:destroy -->
