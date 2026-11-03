# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** The OpenBao HTTP API

## Scenario

The `inventory` team runs a nightly reporting job that reads the inventory secrets and lists their names. The job must not use the root token or a token that lives for weeks. You hold the root token of the lab. The job reads its token from a Kubernetes Secret.

## Your task

Use the OpenBao HTTP API (with `curl`, or with the `bao` CLI, which uses the same API):

1. Create a token with the policy `inventory-lister`, a time to live of **15 minutes**, and room for **5 uses**. Give it the display name `report-job`.
2. Store the token, unused, in a Kubernetes Secret named `report-token` in the namespace `api-demo`, under the key `token`.

## Constraints

- Do not use the token yourself. Every request, including a lookup made with the token, uses one of its five uses. Check it with the root token if you need to.
- The token must not have the policy `root`, and it must not have `inventory-writer`.
- Do not change the policies.

## Done when

- The token in `report-token` has the policies `default` and `inventory-lister` only.
- Its creation TTL is 900 seconds and it still has 5 uses.
