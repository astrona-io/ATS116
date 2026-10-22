# Talk To OpenBao Over HTTP

OpenBao answers every client through one HTTP API. The `bao` command-line tool is a thin layer on top of it: `bao kv get secret/inventory/config` sends a `GET` request to `/v1/secret/data/inventory/config` and prints the JSON it gets back in a friendlier form. When you know the request underneath, you can debug any client, because you can send the same request yourself.

This module is about those requests. Keep one sentence in mind: **every request names a path under `/v1/`, carries a token in the `X-Vault-Token` header, and gets back JSON with either `data` or an `errors` list.** The API path is the same path the policies talk about, so reading a request also tells you which policy rule it needs.

The module has three parts. **Requests, Tokens And Responses** sends unauthenticated and authenticated requests and takes a response and an error apart. **Logging In, Reading, Writing And Listing** logs in with userpass and AppRole and works with KV version 2 secrets, where the paths gain `data/` and `metadata/`. **Response Wrapping And Request Headers** hands a secret to someone else as a single-use wrapping token. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Name the parts of an OpenBao API request: method, `/v1/` path, `X-Vault-Token` header and JSON body.
- Read a response's `data`, `auth`, `lease_duration`, `wrap_info` and `warnings` fields, and an error's status code and `errors` list.
- Log in over HTTP with userpass and AppRole, and use the token from `auth.client_token`.
- Write, read and list KV version 2 secrets with the right `data/` and `metadata/` paths.
- Use the `LIST` method or `?list=true` to list keys.
- Request a wrapped response with `X-Vault-Wrap-TTL`, and look up and unwrap a wrapping token.

## Before you start

You need `curl` and `jq` on your machine, and the basics of OpenBao: a token is the credential OpenBao checks on every request, and a policy lists what a token may do on which paths.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. It contains:

| Object | What it is |
| --- | --- |
| KV version 2 at `secret/` | Secrets `secret/inventory/config`, `secret/inventory/api` and `secret/inventory/billing` |
| Userpass user `deployer` | Password `deployer-password` (lab-only), policy `inventory-writer`: write and read under `secret/inventory/`, and list it |
| AppRole `report` | Policy `inventory-lister`: read under `secret/inventory/` and list it |
| `tester` (namespace `clients`) | A pod with `curl` and `jq` |

The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there. Every part starts the same way: a port-forward in a second terminal, and two variables in your shell.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
