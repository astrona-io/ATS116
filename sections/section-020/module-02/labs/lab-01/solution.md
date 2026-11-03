# Solution: Hand An Agent A Wrapped Secret ID

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks two things: the role has the required policy and limits, and the Secret holds the real role ID and a wrapping token that is still unused, was created for the secret ID path of the role and has a 300 second TTL.

## Step 1: Connect to OpenBao

Start the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), then set the address and the lab-only root token:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

## Step 2: Create the role

```sh
bao write auth/approle/role/nightly \
  token_policies=inventory-reader \
  token_ttl=20m \
  secret_id_ttl=10m \
  secret_id_num_uses=1
bao read auth/approle/role/nightly
```

Check that `token_policies` lists only `inventory-reader`, and that `secret_id_ttl`, `secret_id_num_uses` and `token_ttl` show the values you set.

## Step 3: Read the role ID and create a wrapped secret ID

```sh
ROLE_ID="$(bao read -field=role_id auth/approle/role/nightly/role-id)"
WRAP_TOKEN="$(bao write -wrap-ttl=5m -f -field=wrapping_token auth/approle/role/nightly/secret-id)"
```

The `-wrap-ttl=5m` flag makes OpenBao return a wrapping token instead of the secret ID. Do not unwrap it and do not look up anything with it except through `sys/wrapping/lookup`.

## Step 4: Store both values in the Secret

```sh
kubectl -n agent-demo create secret generic nightly-approle \
  --from-literal=role-id="$ROLE_ID" \
  --from-literal=wrapped-secret-id="$WRAP_TOKEN"
```

Submit now. The wrapping token lives for only 5 minutes, and the grader needs it before it expires. If you took longer, create a new wrapping token and replace the Secret with `kubectl -n agent-demo delete secret nightly-approle` followed by the create command.

## Step 5: Check without using the token

```sh
bao write sys/wrapping/lookup token="$WRAP_TOKEN"
```

The `creation_path` should be `auth/approle/role/nightly/secret-id` and `creation_ttl` should be 300 seconds. A lookup does not consume the wrapping token. `bao unwrap` would, and the lab would then fail.

## Common mistakes

- Setting `secret_id_ttl` but not `secret_id_num_uses`, so the secret ID can be used many times.
- Creating the secret ID without `-wrap-ttl` and storing the secret ID itself in the Secret.
- Unwrapping the token to see what is inside. Unwrapping can be done once.
- Waiting more than 5 minutes between creating the wrapping token and submitting.
