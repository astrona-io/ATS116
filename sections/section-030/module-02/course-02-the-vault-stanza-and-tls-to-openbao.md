# The vault Stanza And TLS To OpenBao

The `vault` stanza tells the proxy where OpenBao is and how to trust it. The stanza keeps the name `vault`; OpenBao has not renamed it. A proxy that talks to OpenBao over plain HTTP sends its login and every token over the network without protection. This part shows the settings that make the connection safe and tolerant of short failures.

## The address

```hcl
vault {
  address = "https://openbao.openbao.svc:8200"
}
```

The address is the URL of an OpenBao server or of a load balancer in front of the nodes. The environment variable `BAO_ADDR` sets the same value, and the stanza overrides it. The playground uses `http://openbao.openbao.svc:8200`, because the lab-only installation has no TLS. A real installation uses `https`.

## Trusting the server

When the server's certificate is signed by a private CA, the proxy must know that CA:

```hcl
vault {
  address = "https://openbao.openbao.svc:8200"
  ca_cert = "/etc/openbao-ca/ca.crt"
}
```

| Setting | What it does |
| --- | --- |
| `ca_cert` | A file with the CA certificate that signed the server certificate |
| `ca_path` | A directory of CA certificates |
| `client_cert`, `client_key` | A certificate and key for the proxy, when the server asks for one |
| `tls_server_name` | The name to check in the server certificate, when the address uses another name |
| `tls_skip_verify` | Does not check the server certificate at all |

Never set `tls_skip_verify = true` outside a test. The proxy would then accept any server that answers, including one that is not OpenBao, and would send it its token. Mount the CA certificate from a ConfigMap into the proxy container and use `ca_cert`.

## Retrying

`retry` sets how often the proxy repeats a request that failed to reach OpenBao:

```hcl
vault {
  address = "https://openbao.openbao.svc:8200"
  retry {
    num_retries = 5
  }
}
```

A restart of OpenBao, or a leader change, can fail a request for a few seconds. A few retries hide that from the application. Too many retries make a slow failure of every request when OpenBao is really down.

## What the proxy does when OpenBao is not reachable

The login in `auto_auth` is also a request to OpenBao. If it fails, the proxy retries it with a back-off, the way the agent does, and keeps running. Requests that arrive in the meantime and need the auto-auth token have none to use, and they fail. Once the login succeeds, requests work again without a restart.

## Try it

1. Change the `vault` address in the playground to `http://openbao.openbao.svc:8201`, where nothing listens, and restart the pod.
2. Call `/config` from the `tester` pod, then read `kubectl -n proxy-demo logs deploy/inventory -c proxy | tail -n 20`. The log shows that the login fails, and the request fails.
3. Put the right address back and restart.

## Common pitfalls

> [!WARNING]
> - **Setting `tls_skip_verify = true` "just for now".** It stays. Fix the CA instead.
> - **Using a different host name from the one in the certificate.** Use `tls_server_name` to name the one in the certificate.
> - **Changing the stanza and not restarting.** The proxy reads its configuration at start.
> - **Expecting a restart to be needed after OpenBao comes back.** The proxy logs in again by itself.
