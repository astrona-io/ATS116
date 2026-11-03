# Tokens, Permissions And Server State Over HTTP

A client that works for a day and then fails with `permission denied` has usually run into a token problem: the token expired, it ran out of uses, or its policies never allowed the path. The fastest way to tell is to ask OpenBao about the token, the policies and the server itself, and each of those questions is one HTTP request.

This module is about those questions. Keep one sentence in mind: **a token is an object with a lifetime, a use limit and a list of policies, and the API lets you read all three.** The same API tells you whether the server is sealed, whether it is the active node and what a failed request means.

The module has four parts. **The Token Lifecycle** looks up, renews, creates and revokes tokens; a graded lab follows it. **Finding Out What A Token Can Do** reads policies and asks OpenBao for the capabilities of a token on a path. **Server State, Health And Error Codes** reads the health endpoint and the status codes of failed requests. **The bao Command As An HTTP Client** shows the request behind each `bao` command, so you can move between the command and `curl`.

## Learning objectives

After this module you can:

- Read the TTL, use limit, policies and type of a token with `lookup-self`.
- Renew a token with `renew-self`, create a limited child token and revoke a token.
- Explain service tokens, batch tokens, periodic tokens, orphan tokens and the parent and child relationship.
- Ask OpenBao for a token's capabilities on a path, and read a policy through the API.
- Read the status codes of `sys/health` and the `errors` list of a failed request.
- Print the `curl` command behind any `bao` command.

## Before you start

You need `curl` and `jq` on your machine, and the basics of OpenBao: a token is the credential OpenBao checks on every request, and a policy lists what a token may do on which paths. You also need to know how to log in over HTTP and read a KV version 2 secret.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. It contains:

| Object | What it is |
| --- | --- |
| KV version 2 at `secret/` | Secrets `secret/inventory/config`, `secret/inventory/api` and `secret/inventory/billing` |
| Userpass user `deployer` | Password `deployer-password` (lab-only), policy `inventory-writer`: write and read under `secret/inventory/`, and list it |
| AppRole `report` | Policy `inventory-lister`: read under `secret/inventory/` and list it |
| `tester` (namespace `clients`) | A pod with `curl` and `jq` |

The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there. Every part starts the same way: a port-forward in a second terminal, and variables in your shell.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
