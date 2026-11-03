# Listeners, TLS And Token Control In OpenBao Proxy

A proxy has two sides. On one side the application sends it requests. On the other side the proxy talks to OpenBao. Each side has settings, and each setting decides who can use the proxy's access and how safely the proxy reaches the server. A wrong value on either side does not always cause an error. It can leave the proxy open to every pod, or make it forward a token that OpenBao refuses.

This module is about those settings. Keep one sentence in mind: **the proxy lends its identity to every request it accepts, so decide who can reach it, how it reaches OpenBao, and whose token it sends.**

The module has four parts. **Listeners And Who Can Reach The Proxy** covers TCP and Unix socket listeners, TLS and `require_request_header`. **The vault Stanza And TLS To OpenBao** covers the address, the CA certificate and the retry settings. **Whose Token The Proxy Sends** covers `false`, `true` and `"force"`; a graded lab follows it. **Logs And Troubleshooting** maps symptoms to causes.

## Learning objectives

After this module you can:

- Configure a TCP or Unix socket listener and explain what each address exposes.
- Turn on TLS for a listener and require the `X-Vault-Request` header.
- Set `address`, `ca_cert`, `tls_server_name` and `retry` in the `vault` stanza.
- Explain the behaviour of `use_auto_auth_token` set to `false`, `true` and `"force"`.
- Read the proxy's log and tell a login failure from a refused request.

## Before you start

You need to know how the proxy runs as a sidecar and what auto-auth is, both from the previous module. You also need to read an HTTP status code and a Kubernetes ConfigMap.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. The namespace **`proxy-demo`** runs the `inventory` pod with a `proxy` container and an `nginx` container. The web server has three paths:

| Path | What it forwards to the proxy |
| --- | --- |
| `/config` | The inventory secret, with no token of its own |
| `/legacy` | The inventory secret, with a made-up `X-Vault-Token` header |
| `/whoami` | A lookup of the token the proxy used, with the `X-Vault-Request` header |

In OpenBao, the Kubernetes auth role `inventory-proxy` binds the service account `inventory-proxy` to the policy `inventory-reader`. The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
