# Summary

A proxy lends its identity to every request it accepts. The settings of the proxy decide who can reach it, how it reaches OpenBao and whose token it sends.

## What you learned

A `tcp` listener on `127.0.0.1` is reachable only from the pod. On `0.0.0.0` it is reachable from the cluster. A `unix` listener is protected by file permissions. TLS belongs on any listener that is not on loopback. `require_request_header` refuses requests without `X-Vault-Request: true`; it stops accidents, not callers.

The `vault` stanza sets the OpenBao `address`, the CA with `ca_cert` or `ca_path`, a client certificate, `tls_server_name` and `retry`. `tls_skip_verify` makes the proxy trust any server and should not leave a test. If OpenBao is not reachable, the login is retried with a back-off and requests wait for it.

`use_auto_auth_token` set to `false` never adds the proxy's token, set to `true` adds it only to requests with no token, and set to `"force"` replaces any token on the request. A stale token with `true` is forwarded and refused. To find a fault, read the application's answer, call the proxy from inside the pod, read the proxy's log, and compare the role with the service account. The key facts to remember are these:

- Loopback listener for the application and no other way in.
- Trust OpenBao with `ca_cert`, never `tls_skip_verify`.
- `"force"` is a string and makes the proxy's identity the only one.
- Change one setting, restart, repeat the failing request.

<!-- astrona:playground:destroy -->
