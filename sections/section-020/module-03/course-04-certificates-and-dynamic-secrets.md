# Certificates And Dynamic Secrets

A password in a KV secret changes when someone changes it. A certificate has an end date, and a certificate in a file that is never renewed becomes an outage on that date. The PKI secrets engine issues short-lived certificates, and the agent can write them to files and issue new ones before the old ones expire. This part shows the template function for that and what the playground does.

## What the PKI engine gives you

The playground has a PKI secrets engine at `pki/` with a root certificate and a role `web`. The role allows the domain `inventory.example.com` and its subdomains, with a maximum TTL of one hour. A client asks the role for a certificate with `pki/issue/web`, and OpenBao returns the certificate, the private key and the issuing CA. The `pki-issuer` policy allows only the `update` capability on `pki/issue/web`, and the `inventory-agent` role carries it.

You can see the issue request outside the agent. Each call issues a new certificate with a new serial number:

```sh
bao write pki/issue/web common_name=app.inventory.example.com ttl=10m
```

The response includes `certificate`, `private_key`, `ca_chain`, `issuing_ca` and `serial_number`. Anyone with this response holds the private key, so treat it like a password.

## The pkiCert function

In a template, `pkiCert` issues a certificate and gives you its parts:

```hcl
template {
  destination = "/etc/inventory/tls.crt"
  contents    = <<EOT
{{ with pkiCert "pki/issue/web" "common_name=app.inventory.example.com" "ttl=2m" }}{{ .Cert }}{{ .CA }}{{ end }}
EOT
}
```

The function takes the issue path, followed by the request parameters as `key=value` strings. Inside `with`, `.Cert` is the certificate, `.Key` the private key and `.CA` the issuing CA. Write the key into its own template with `perms = "0600"`, and do not serve it. The playground's web server serves `/tls.crt` only, which holds public data.

## When the certificate is issued again

A certificate from `pkiCert` has no lease. The agent tracks its end date and renders the template again before it expires. The next render issues a new certificate with a new serial number and writes the file. If the template has a `command`, it runs after each render, which is how a service learns about a new certificate.

Short TTLs make this visible in a playground. With `ttl=2m` a new certificate appears about every two minutes. In production use a TTL that gives you time to notice a failure: a one-hour TTL with a failing PKI engine gives you less time than a 24-hour TTL.

## Other dynamic secrets

The same mechanism works for any engine that returns leases. A database role renders a username and password with `{{ with secret "database/creds/readonly" }}{{ .Data.username }}{{ .Data.password }}{{ end }}`. The agent renews the lease and, when the lease reaches its maximum TTL, reads the path again and writes the new credential. Revoking the lease in OpenBao makes the old credential stop working at the database, and the agent notices on its next check.

| Secret kind | Render trigger |
| --- | --- |
| KV version 2 | `static_secret_render_interval` |
| Lease from a secrets engine | Before the lease runs out |
| `pkiCert` certificate | Before the certificate expires |

## Try it

1. In the playground, edit `agent-config`, and add the `tls.crt` template from this part. Add `error_on_missing_key = true`.
2. Restart the pod and read `/tls.crt` from the `tester` pod. Extract the serial number with `openssl x509 -noout -serial` if the tool is available on your machine, or compare the file with `diff` after the next render.
3. Wait for the 2-minute TTL to run out. The file changes without a restart; check `kubectl -n agent-demo logs deploy/inventory -c agent`.

## Common pitfalls

> [!WARNING]
> - **Serving the private key.** Put the key in a separate file with `perms = "0600"`, and mount it only into the container that needs it.
> - **Asking for a TTL longer than the role's `max_ttl`.** OpenBao caps it, or refuses the request, depending on the settings.
> - **A policy that lacks `update` on the issue path.** The login works, the template fails, and the log shows a `permission denied` for the path.
> - **Assuming revocation reaches the file.** The agent renders again because of the end date. Do not rely on it to react to a revoked certificate.
