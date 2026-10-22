# Deliver Secrets To Pods With The Agent Injector

The `inventory` app in this module is an `nginx` server that serves `/vault/secrets/config.env` at `/config`. Its Deployment has no agent container and no extra volume, only a few annotations on its pod template. When Kubernetes creates the pod, the agent injector reads those annotations and adds OpenBao Agent to the pod: an init container that writes the file before `nginx` starts, and a sidecar that keeps it up to date.

The agent injector is a Kubernetes mutating admission webhook: a service the Kubernetes API server calls before it stores a new pod, and which may change the pod. Keep one sentence in mind: **the annotations go on the pod template, the role must match the pod's service account, and the application only reads a file.**

The module has three parts. **How The Agent Injector Works** looks at what the Helm chart installed and at an injected pod. **Annotations And Templates** writes the annotations for a secret, its template and its render interval; a graded lab follows it. **Troubleshooting Injection** walks through the ways injection fails and the one command that tells them apart.

## Learning objectives

After this module you can:

- Explain what a mutating admission webhook does, and which component injects the agent.
- Explain why the injector's annotations and paths say `vault`, and which OpenBao version actually runs.
- Write the annotations for a secret, a template, a role and a render interval on a pod template.
- Bind a Kubernetes auth role to an application's service account with a narrow policy.
- Tell apart a pod that was not injected from an injected pod whose agent cannot log in or render.
- Choose between the injector, an agent sidecar you write yourself, and OpenBao Proxy.

## Before you start

You need Kubernetes basics: Deployments and their pod templates, annotations, init containers, service accounts, `kubectl describe` and `kubectl logs -c`. You also need to know that a Kubernetes auth role in OpenBao binds a service account to policies, and that a KV version 2 secret's fields are at `.Data.data` in a template.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed, and the agent injector. The namespace **`inventory`** runs:

| Object | What it is |
| --- | --- |
| Deployment `inventory` | One container, `app` (`nginx:1.27-alpine`), with injector annotations on its pod template |
| ConfigMap `nginx-conf` | Makes `nginx` serve `/vault/secrets/config.env` at `/config` |
| ServiceAccount `inventory` | The identity the injected agent logs in with |
| Service `inventory` | Port `80`, reachable from the `tester` pod in the namespace `clients` |

In OpenBao, the Kubernetes auth role `inventory` binds that service account to the policy `inventory-reader`. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
