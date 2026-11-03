# Listeners And Who Can Reach The Proxy

Every request the proxy accepts is sent to OpenBao with the proxy's token. So whoever can send a request to a listener has the proxy's access. This part lists what a listener can be, what each choice exposes and what the settings add.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## TCP listeners

A `listener "tcp"` stanza binds an address and a port:

```hcl
listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}
```

The address decides who can connect.

| Address | Who can connect |
| --- | --- |
| `127.0.0.1:8100` | Processes that share the network namespace, which is every container in the same pod |
| `0.0.0.0:8100` | Anything that can route to the pod's IP address, including every other pod in the cluster unless a network policy blocks it |
| The pod IP | Same as `0.0.0.0` for traffic that arrives on that address |

`tls_disable = true` turns TLS off. On a loopback address inside a pod this is usual: the traffic never leaves the pod. On any other address, turn TLS on.

## Unix socket listeners

A `listener "unix"` stanza uses a file instead of a port. Access is then a file permission, not a network rule:

```hcl
listener "unix" {
  address     = "/run/proxy/proxy.sock"
  tls_disable = true
  socket_mode = "0660"
}
```

Only containers that mount the directory with the socket can connect, and `socket_mode`, `socket_user` and `socket_group` decide which users in them can. The application must be able to send HTTP over a Unix socket. `nginx` can, with `proxy_pass http://unix:/run/proxy/proxy.sock:/v1/...`; many HTTP clients can too.

## TLS on a listener

For a listener that is not on loopback, set the certificate and key:

```hcl
listener "tcp" {
  address       = "0.0.0.0:8100"
  tls_cert_file = "/etc/proxy-tls/tls.crt"
  tls_key_file  = "/etc/proxy-tls/tls.key"
}
```

`tls_min_version` sets the lowest protocol version. `tls_client_ca_file` with `tls_require_and_verify_client_cert = true` makes clients present a certificate that the CA signed. A client certificate limits who can connect, but it still gives the connected client the proxy's access.

## Requiring a header

`require_request_header = true` makes the listener refuse any request without the header `X-Vault-Request: true`. A browser that follows a link, or a service that forwards a user-supplied URL, does not add this header on its own. The setting helps against requests the application sent by mistake, for example through a server-side request forgery. It does not authenticate the caller.

## More than one listener

The proxy can have several listeners, for example one on loopback for the application and none on any other address. Do not add a second listener for convenience. Every listener is another way in.

## Try it

1. In the playground, call `/config` from the `tester` pod and note that it works.
2. Change the listener address to `0.0.0.0:8100` with `kubectl -n proxy-demo edit configmap proxy-config`, and restart the pod.
3. Find the pod address with `kubectl -n proxy-demo get pod -l app=inventory -o jsonpath='{.items[0].status.podIP}'` and call `http://<pod ip>:8100/v1/secret/data/inventory/config` from the `tester` pod with `curl -s`. The secret is returned with no token.
4. Put `127.0.0.1` back, restart, and repeat the request. It now fails to connect.
5. Add `require_request_header = true` to the listener, restart, and call `/config`. The request now fails because `nginx` does not send the header. Remove the setting again.

## Common pitfalls

> [!WARNING]
> - **Binding `0.0.0.0` "to make it work".** Every pod that can reach the pod's address can read what the proxy can read, with no token.
> - **Treating `require_request_header` as authentication.** It stops accidents, not a caller who sets the header.
> - **Using a client certificate and assuming it limits what the client can do.** It limits who connects, not which paths they call.
> - **Adding a Service port for the proxy.** The Service should expose the application's port only.
