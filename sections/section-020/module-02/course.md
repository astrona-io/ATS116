# Auto-Auth Methods, Secret IDs And Sinks

A pod on Kubernetes can log in with its service account. A program on a virtual machine, in a build system or in another cluster has no service account, so it needs another way to prove who it is. OpenBao Agent supports several auto-auth methods for this, and each one raises the same question: how does the first credential reach the agent safely?

This module is about that question. Keep one sentence in mind: **the agent can only be as safe as the first credential it receives, so give it a credential that is short-lived, used once and delivered wrapped.** The module uses the AppRole method as the main example, because it is the method for programs that run outside Kubernetes.

The module has four parts. **AppRole Roles And Secret IDs** reads a role, the role ID and the secret ID, and the limits that make a secret ID safe. **Delivering A Secret ID Wrapped** wraps the secret ID and lets the agent unwrap it; a graded lab follows it. **Other Auto-Auth Methods** compares `jwt`, `cert`, `token_file` and the cloud methods, and the settings every method shares. **Sink Options And Token Sharing** covers the file mode of a sink, wrapped sinks and more than one sink.

## Learning objectives

After this module you can:

- Explain the role ID and the secret ID of an AppRole, and why the agent needs both.
- Set `secret_id_ttl`, `secret_id_num_uses`, `token_ttl` and `token_bound_cidrs` on a role.
- Create a wrapped secret ID and configure the agent with `secret_id_response_wrapping_path`.
- Choose between the `approle`, `jwt`, `cert`, `token_file`, `kubernetes` and cloud methods.
- Set `min_backoff`, `max_backoff`, `exit_on_err` and `wrap_ttl` on a method.
- Set the mode of a `file` sink, wrap a sink, and use more than one sink.

## Before you start

You need to know what an OpenBao token and a policy are, and what a KV version 2 secret is. You also need to know that OpenBao Agent reads one HCL file with `vault`, `auto_auth` and `template` stanzas.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. The namespace **`agent-demo`** runs the same `inventory` pod as before: an `agent` container and an `nginx` container sharing an in-memory volume. In OpenBao:

| Object | What it is |
| --- | --- |
| KV version 2 at `secret/` | The secret `secret/inventory/config` |
| AppRole auth method at `auth/approle` | The role `nightly`, with the policy `inventory-reader` |
| Kubernetes auth role `inventory-agent` | The login the playground's agent uses |
| `tester` (namespace `clients`) | A pod with `curl` and `jq` |

The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
