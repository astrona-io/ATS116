# Give Applications A Token-Free Path With OpenBao Proxy

The `inventory` app in this module is an `nginx` server that answers `/config` by forwarding the request to an OpenBao API path. It sends no token. Next to it in the same pod runs OpenBao Proxy, which logs in with the pod's service account and adds its own token to every request it forwards. The app gets the secret; the token never leaves the proxy.

OpenBao Proxy is a client process, started with `bao proxy`, that forwards HTTP API requests to OpenBao. Keep one sentence in mind: **the proxy turns "anyone who can reach me" into "the identity I logged in as", so only the application may reach it.** That is why it listens on `127.0.0.1` inside the pod.

The module has three parts. **The API Proxy And The Auto-Auth Token** reads the proxy configuration and follows one request through it. **Running The Proxy Next To The Application** explains the sidecar pattern and why the listener must stay inside the pod; a graded lab follows it. **Caching Tokens And Leases** shows what the proxy keeps and renews, and how to clear it.

## Learning objectives

After this module you can:

- Read and write an OpenBao Proxy configuration with `vault`, `auto_auth`, `api_proxy` and `listener` stanzas.
- Explain `use_auto_auth_token = true` and `"force"`.
- Run the proxy as a sidecar that logs in with the pod's service account.
- Keep the proxy reachable only from inside its own pod, and prove it.
- Explain which responses the proxy caches and renews, and clear its cache.
- Choose between OpenBao Proxy and OpenBao Agent for an application.

## Before you start

You need Kubernetes basics: Deployments, pods with more than one container, ConfigMaps, Services, service accounts and `kubectl exec -c`. You also need to know that a Kubernetes auth role in OpenBao binds a service account to policies, and that a KV version 2 secret's fields are at `.data.data` in an API response.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. The namespace **`proxy-demo`** runs:

| Object | What it is |
| --- | --- |
| Deployment `inventory` | Two containers: `proxy` (OpenBao Proxy 2.7.1) and `app` (`nginx:1.27-alpine`) |
| ConfigMap `proxy-config` | The proxy configuration file `proxy.hcl` |
| ConfigMap `nginx-conf` | Makes `nginx` forward `/config` to `http://127.0.0.1:8100/v1/secret/data/inventory/config` |
| ServiceAccount `inventory-proxy` | The identity the proxy logs in with |
| Service `inventory` | Port `80` only, reachable from the `tester` pod in the namespace `clients` |

In OpenBao, the Kubernetes auth role `inventory-proxy` binds that service account to the policy `inventory-reader`, which may read `secret/data/inventory/*`. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
