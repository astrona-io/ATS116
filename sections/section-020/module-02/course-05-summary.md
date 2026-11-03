# Summary

OpenBao Agent can only be as safe as the first credential it receives. The auto-auth methods differ in what that credential is, and the safest choices give the agent a credential that is short-lived, limited in uses and delivered wrapped.

## What you learned

AppRole logs in with two values. The role ID names the role and is not secret. The secret ID is the password, created on request. A role limits the secret ID with `secret_id_ttl`, `secret_id_num_uses` and `secret_id_bound_cidrs`, and limits the token with `token_ttl`, `token_max_ttl` and `token_bound_cidrs`. A secret ID that works once turns a leak into a visible failure. Accessors let an administrator look up or destroy a secret ID without seeing it.

Response wrapping keeps a secret ID out of logs and tickets. OpenBao stores the response in a cubbyhole and returns a single-use wrapping token. The receiver checks the token with `sys/wrapping/lookup`, which does not use it. The agent unwraps it when `secret_id_response_wrapping_path` names the expected creation path. A failed unwrap means someone else used the token first, and the secret ID must be replaced.

The agent supports `kubernetes`, `approle`, `jwt`, `cert`, `token_file` and cloud methods. Choose the one the workload already has a proof of identity for. Every method accepts `mount_path`, `namespace`, `wrap_ttl`, `min_backoff`, `max_backoff` and `exit_on_err`. A sink writes the token to a file with a chosen `mode`, can wrap the token, can encrypt it, and can be repeated. The file is a bearer credential, so only containers that need it should see it. The key facts to remember are these:

- Role ID is not secret; secret ID is. Limit it with TTL and uses.
- Wrap the secret ID, look it up with `sys/wrapping/lookup`, never unwrap it to test.
- `secret_id_response_wrapping_path` makes the agent unwrap.
- Remove the sink if no other process needs the token.

<!-- astrona:playground:destroy -->
