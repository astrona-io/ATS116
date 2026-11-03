# Roles, Auth Paths And Connections

Some annotations decide how the agent logs in and where it connects. An application team sets one of them, the role. The rest are for the platform team, and an application team that changes them makes its pods behave differently from every other pod in the cluster. This part shows the annotations in that second group, and what each can break.

## The role

`vault.hashicorp.com/role` names the Kubernetes auth role the agent logs in with. It is required. The role must bind the pod's service account and namespace, and it decides the policies of the token. An application team changes it when it needs a different set of policies, for example one role per environment.

Because the role is the only annotation that picks permissions, keep the policies on the role narrow. An application team should not be able to name a role with wide policies for its service account.

## The auth path

`vault.hashicorp.com/auth-path` names the mount of the auth method. The default is `auth/kubernetes`. A cluster with more than one Kubernetes auth mount, one per cluster, sets it on every pod to the mount for its cluster:

```yaml
vault.hashicorp.com/auth-path: "auth/kubernetes-prod"
```

A path that does not exist makes the login fail with a not-found error in the init container's log.

## The auth type

`vault.hashicorp.com/auth-type` defaults to `kubernetes`. Other auth types with the `auth-config-*` annotations exist, but they are rarely used with the injector, because the service account token is already in every pod.

## The OpenBao address and TLS

The address comes from the injector's configuration, not from the pod, so that one cluster talks to one OpenBao. The annotations that control TLS to OpenBao are:

| Annotation | What it does |
| --- | --- |
| `vault.hashicorp.com/ca-cert` | The path of a CA certificate file in the pod |
| `vault.hashicorp.com/tls-secret` | A Kubernetes Secret with the CA and client certificate to mount |
| `vault.hashicorp.com/tls-server-name` | The name to check in the server certificate |
| `vault.hashicorp.com/tls-skip-verify` | Does not check the server certificate |

`tls-skip-verify` gives the same risk as in the agent and the proxy: the agent sends its login to any server that answers. Do not set it outside a test.

## Namespaces

`vault.hashicorp.com/namespace` selects an OpenBao namespace for the login and the reads. It is empty by default, the root namespace.

## Who may set which annotation

The injector acts on every annotation that a pod has, from whoever created the pod. That means a team can set `auth-path`, `tls-skip-verify` or `agent-image` on its own pods. To limit that, use admission policies in Kubernetes that allow only certain annotations or values, and keep the roles narrow, so that the worst thing a changed annotation can do is stay within one application's secrets.

## A map of the annotations

| Group | Annotations | Usually set by |
| --- | --- | --- |
| Which secrets and files | `agent-inject-secret-*`, `-template-*`, `-file-*`, `-perms-*`, `-command-*` | The application team |
| Identity | `role` | The application team |
| Agent containers | `agent-requests-*`, `agent-limits-*`, `agent-init-first`, `agent-pre-populate*` | Application team, within platform rules |
| Connection | `auth-path`, `namespace`, `ca-cert`, `tls-*` | The platform team |

## Try it

1. In the playground, change the `role` annotation to a name that does not exist and let the Deployment roll out. Read the init container's log with `init_log`.
2. Put the role back.
3. Add `vault.hashicorp.com/auth-path: "auth/kubernetes-prod"` and read the log. The error names the path.
4. Remove the annotation again and check that the new pod becomes ready.

## Common pitfalls

> [!WARNING]
> - **Letting every team choose its own role without limits.** A wide role for one team is available to anyone who can write the annotation.
> - **Setting `tls-skip-verify` to get past a certificate error.** Fix the CA.
> - **Pointing `auth-path` at the wrong cluster's mount.** The login fails or, worse, succeeds against another cluster's role.
> - **Confusing the OpenBao namespace with the Kubernetes namespace.** They are unrelated.
