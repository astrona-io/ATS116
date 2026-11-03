# Annotations In Depth

The annotations on a pod template are the injector's whole interface. A team that deploys an application never writes an agent configuration; it writes annotations, and the injector turns them into one. Most of the annotation names follow a pattern, and a few settings change how the agent containers run. Knowing the pattern lets you read any annotated Deployment, and knowing the settings lets you tune the agent without writing a second container.

This module is about the annotations themselves. Keep one sentence in mind: **`agent-inject-secret-<name>` creates a file named `<name>`, and every other annotation with the same `<name>` shapes that file.**

The module has four parts. **Several Secrets, Several Files** covers the unique name, the file name and the path. **Shaping The Files** covers templates, permissions and commands; a graded lab follows it. **Tuning The Agent Containers** covers resources, ordering, the one-shot mode and the token file. **Roles, Auth Paths And Connections** covers the annotations that decide how the agent logs in and reaches OpenBao.

## Learning objectives

After this module you can:

- Inject more than one secret into one pod and control the file name and the directory.
- Write a template annotation for env, JSON and multi-secret files, and explain the default output.
- Set the file mode with `agent-inject-perms-<name>` and run a command after a render with `agent-inject-command-<name>`.
- Set CPU and memory requests and limits for the injected containers, and order the agent before other init containers.
- Use `agent-pre-populate-only`, `agent-inject-token` and `agent-revoke-on-shutdown` and explain what each changes.
- Set `role`, `auth-path`, `namespace` and the TLS annotations, and say which of them an application team should change.

## Before you start

You need to know how the injector adds an init container and a sidecar, how the status annotation shows that a pod was injected, and what a Kubernetes auth role is. The previous module introduces all three.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the agent injector. The namespace **`inventory`** runs:

| Object | What it is |
| --- | --- |
| Deployment `inventory` | One container, `app` (`nginx:1.27-alpine`), with injector annotations for `config.env` only |
| ConfigMap `nginx-conf` | Serves `/vault/secrets/config.env` at `/config` and `/vault/secrets/api.json` at `/api` |
| ServiceAccount `inventory` | The identity the injected agent logs in with |

In OpenBao there are two secrets, `secret/inventory/config` and `secret/inventory/api`, and the Kubernetes auth role `inventory` with the policy `inventory-reader`, which reads `secret/data/inventory/*`. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
