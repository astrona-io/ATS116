# Summary

Every OpenBao client, from the `bao` command-line tool to an injected sidecar, sends HTTP requests to paths under `/v1/`. Knowing those requests lets you reproduce any client's failure with `curl` and read the real answer instead of a one-line message.

## What you learned

A request names a path and a method and carries its token in the `X-Vault-Token` header, or as `Authorization: Bearer`. The header name still says Vault because OpenBao keeps the names of the project it was forked from. A few paths, such as `sys/health` and `sys/wrapping/lookup`, need no token. A response carries the answer in `data`, a login's new token in `auth.client_token`, lease details for dynamic secrets, and `wrap_info` for a wrapped answer. An error carries only a status code and an `errors` list: `403` points at the token or its policy, `404` at a path that does not exist.

KV version 2 splits every secret into a `data/` path for its values and a `metadata/` path for its versions and names. Writes put the fields inside a `data` object, reads return them in `.data.data`, and lists use the `LIST` method or `?list=true` on the `metadata/` path. A person logs in with userpass and a password; a program logs in with AppRole and a role ID plus a secret ID. Either way the token it gets back carries only the policies of that identity.

Response wrapping hands a secret over safely. The `X-Vault-Wrap-TTL` header makes OpenBao keep the answer and return a single-use wrapping token. The receiver checks the token with `sys/wrapping/lookup`, which does not use it, and opens it once with `sys/wrapping/unwrap`. A failed first unwrap means someone else opened it, and the secret must be replaced. The key facts to remember are these:

- `/v1/<path>`, the `X-Vault-Token` header, JSON in and out.
- Logins fill `auth`, not `data`.
- KV version 2: `secret/data/...` for values, `secret/metadata/...` for lists and versions.
- A wrapping token works once; look it up, do not unwrap it, to check it.

<!-- astrona:playground:destroy -->
