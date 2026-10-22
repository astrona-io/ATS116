# Render Secrets Into Files With OpenBao Agent

The `inventory` app is an `nginx` web server that serves one file, its configuration, at the address `/config`. It knows nothing about OpenBao and should not have to. In this module a second container in the same pod, OpenBao Agent, logs in to OpenBao, reads `secret/inventory/config`, and writes it into that file. When the secret changes in OpenBao, the agent writes the file again, and the app serves the new value without a restart.

OpenBao Agent is a client process, started with `bao agent`, that does three jobs for an application: it logs in on its own, it keeps its token renewed, and it renders secrets into files or environment variables. Keep one sentence in mind: **auto-auth gets the token, the template uses it, and the application only ever reads a file.**

The module has three parts. **Auto-Auth And Sinks** looks at how the agent logs in with the pod's service account and where it keeps the token. **Rendering Secrets With Templates** writes the configuration file and makes it follow a new secret version; a graded lab follows it. **Secrets As Environment Variables With Process Supervisor Mode** passes the same secret to a program as environment variables instead of a file.

## Learning objectives

After this module you can:

- Explain what auto-auth, a method and a sink are, and read an agent configuration file.
- Configure the `kubernetes` auto-auth method and match it to a Kubernetes auth role.
- Write a template that renders the fields of a KV version 2 secret into a file.
- Explain when the agent renders a secret again, and set `static_secret_render_interval`.
- Read the agent's log to find a failed login or a failed render.
- Run a program with secrets as environment variables in process supervisor mode.

## Before you start

You need Kubernetes basics: Deployments, pods with more than one container, ConfigMaps, service accounts, `kubectl logs -c` and `kubectl exec -c`. You also need to know that a KV version 2 secret keeps its fields under `data` and that a Kubernetes auth role in OpenBao binds a service account to policies.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. The namespace **`agent-demo`** runs:

| Object | What it is |
| --- | --- |
| Deployment `inventory` | Two containers: `agent` (OpenBao Agent 2.7.1) and `app` (`nginx:1.27-alpine`), sharing an in-memory volume at `/etc/inventory` |
| ConfigMap `agent-config` | The agent configuration file `agent.hcl` |
| ConfigMap `nginx-conf` | Makes `nginx` serve `/etc/inventory/config.env` at `/config` |
| ServiceAccount `inventory-agent` | The identity the agent logs in with |
| Service `inventory` | Port `80`, reachable from the `tester` pod in the namespace `clients` |

In OpenBao, the Kubernetes auth role `inventory-agent` binds that service account to the policy `inventory-reader`, which may read `secret/data/inventory/*`. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
