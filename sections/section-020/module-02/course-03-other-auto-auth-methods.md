# Other Auto-Auth Methods

The method decides what proof of identity the agent sends. Kubernetes uses a service account token and AppRole uses a role ID and secret ID. A workload may have neither, but it may have a JSON Web Token (JWT, a signed token that carries claims about the holder), a client certificate, or an identity from a cloud platform. This part compares the methods the agent supports and shows the settings that every method shares.

The commands below need the playground and the port-forward from a second terminal.

## Choosing a method

Choose the method by what the workload already has. A workload that needs a new secret to log in with has not solved the problem; it has moved it.

| Method | Proof of identity | Use it when |
| --- | --- | --- |
| `kubernetes` | The pod's service account token | The workload is a pod |
| `approle` | Role ID and secret ID | The workload has a trusted deployer that can hand over a secret ID |
| `jwt` | A signed JWT from a file | The platform issues JWTs, for example a CI system or a service account projected token |
| `cert` | A TLS client certificate | The workload already has a certificate that OpenBao trusts |
| `token_file` | An existing OpenBao token read from a file | Another process creates the token; the agent only renews it |
| Cloud methods such as `aws`, `azure` and `gcp` | A signed identity document from the cloud platform | The workload runs on a virtual machine or service of that platform |

Each method stanza needs a matching auth method enabled in OpenBao, with a role that describes who may log in. Check which auth methods the playground server has:

<!-- astrona:playground:renew -->

```sh
bao auth list
```

The list holds `approle/`, `kubernetes/` and `token/`. The `token/` method is always present and cannot be disabled. The agent's `mount_path` field names the mount; if you mounted a method at a different path, set `mount_path` to `auth/<path>`.

## The method settings

The Kubernetes method needs only `role`; the agent reads the service account token from its standard path, and `token_path` overrides that path. The `jwt` method needs `role` and `path`, the file that holds the JWT, and removes the file after reading unless `remove_jwt_after_reading` is `false`. The `cert` method uses `name` for the certificate role, and `client_cert` and `client_key` when the certificate is not the one from the `vault` stanza. The `token_file` method takes `token_file_path`.

Here is a `jwt` method in HCL:

```hcl
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      role = "ci-reader"
      path = "/var/run/secrets/tokens/openbao"
    }
  }
}
```

The agent reads the file, sends the JWT with the role name, and OpenBao checks the signature and the claims the role requires. A projected service account token with its own audience is a common source of such a file on Kubernetes.

## Settings every method shares

Besides `config`, a `method` stanza accepts these fields:

| Field | What it does |
| --- | --- |
| `mount_path` | The path where the method is mounted, `auth/<mount>` |
| `namespace` | The OpenBao namespace the login goes to |
| `wrap_ttl` | Asks OpenBao to wrap the login response, so the token reaches the sink wrapped |
| `min_backoff` | The shortest wait after a failed login |
| `max_backoff` | The longest wait after repeated failures |
| `exit_on_err` | Stops the agent after a failed login instead of retrying |

The backoff fields control how hard the agent hits a server that is down. After a failure the agent waits, and the wait grows up to `max_backoff`. In an init container you usually want the opposite: `exit_on_err = true` together with the top-level `exit_after_auth = true`, so that a failed login fails the pod's start.

Check the agent's log for the login that the playground agent made:

```sh
kubectl -n agent-demo logs deploy/inventory -c agent | grep -i auth | head -n 10
```

The lines name the method and report that the authentication succeeded and that the token is renewed on a schedule.

You can now match a workload to a method, write the `jwt` stanza and set the shared fields. The last part of the login path is where the agent puts the token it gets.

## Common pitfalls

> [!WARNING]
> - **Choosing `token_file` and storing a long-lived token in it.** The agent renews tokens, so the token lives as long as it is renewed, and it is a static credential.
> - **Using `jwt` without checking the claims in the role.** The role must bind `bound_audiences` and the subject, or any signed token works.
> - **Forgetting `mount_path`.** The agent logs in at the default mount and the role is not there.
> - **Setting `exit_on_err` in a long-running agent.** A short outage of OpenBao then stops the agent.
