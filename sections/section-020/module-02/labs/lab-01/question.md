# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** OpenBao Agent, AppRole and response wrapping

## Scenario

A nightly job in the namespace `agent-demo` will run OpenBao Agent with the AppRole auto-auth method. The auth method `approle` is already enabled, and the policy `inventory-reader` already exists. Nothing else has been created: the job has no role, and no one has handed it any credentials yet.

The platform team's rule is that the job's secret ID must never be written anywhere in clear text and must be usable only once.

## Your task

1. Create the AppRole `nightly` with these settings:
   - the policy `inventory-reader` and no other policy,
   - a token TTL of 20 minutes,
   - a secret ID that is valid for 10 minutes and can be used exactly once.
2. Create a Kubernetes Secret named `nightly-approle` in the namespace `agent-demo` with two keys:
   - `role-id`: the role ID of the role `nightly`,
   - `wrapped-secret-id`: a wrapping token that wraps a new secret ID of the role `nightly`, with a wrapping TTL of 5 minutes.

## Constraints

- The Secret must not contain the secret ID itself, only the wrapping token. Do not unwrap it.
- Do not use the wrapping token for anything: it must still be unused when you submit.
- Do not change the policy `inventory-reader`.

## Done when

- The role `nightly` has exactly the policy `inventory-reader`, `secret_id_ttl` of 10 minutes, `secret_id_num_uses` of 1 and `token_ttl` of 20 minutes.
- The Secret `nightly-approle` holds the real role ID and a wrapping token that is still valid, was created for `auth/approle/role/nightly/secret-id` and has a TTL of 5 minutes.
