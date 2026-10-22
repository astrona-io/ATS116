# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** The OpenBao HTTP API

## Scenario

The inventory team is moving its reporting service to a new cluster. The service needs a new API key, and the team that runs the service must receive it without the key ever appearing in a chat message, a ticket or a log. You hold the `deployer` account in OpenBao; the receiving team will read a single-use token from a Kubernetes Secret.

## Your task

Use the OpenBao HTTP API (with `curl`, or with the `bao` CLI, which uses the same API):

1. Log in as the userpass user `deployer` with the password `deployer-password`.
2. With the `deployer` token, write the KV version 2 secret `secret/inventory/api` with exactly one field: `api_key` set to `api-key-from-deployer`.
3. With the `deployer` token, read `secret/inventory/api` as a **wrapped** response with a time to live of **10 minutes**.
4. Store the wrapping token, unused, in a Kubernetes Secret named `handover` in the namespace `api-demo`, under the key `wrapping-token`.

## Constraints

- Write the secret with the `deployer` token, not the root token. An audit device records who wrote it.
- **Do not unwrap the wrapping token.** It works once, and the receiving team must be the one to open it. If you used it by mistake, create a new one.
- Do not change the `deployer` user or its policy.

## Done when

- `secret/inventory/api` has `api_key` = `api-key-from-deployer`.
- The audit log shows `deployer` writing `secret/data/inventory/api`.
- The Secret `handover` in `api-demo` holds an unused wrapping token whose creation path is `secret/data/inventory/api` and whose TTL is 600 seconds.
