# Solution: Hand Over A Secret With A Wrapped Response

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the value of `secret/inventory/api`, an audit log entry that shows `deployer` writing it, and an unused wrapping token in the Secret `handover` with the right creation path and a TTL of 600 seconds.

## Step 1: Reach OpenBao

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n openbao port-forward svc/openbao 8200:8200
```

In your first terminal, set the address:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
```

## Step 2: Log in as deployer

A userpass login is a `POST` with the password in the body. The new token is in `auth.client_token`:

```sh
DEPLOYER_TOKEN="$(curl -s -X POST --data '{"password":"deployer-password"}' \
  "$BAO_ADDR/v1/auth/userpass/login/deployer" | jq -r '.auth.client_token')"
echo "$DEPLOYER_TOKEN"
```

If the second line prints `null`, the login failed; send the first request without `| jq ...` and read the `errors` list.

## Step 3: Write the secret as deployer

KV version 2 values go to the `data/` path, inside a `data` object:

```sh
curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" -X POST \
  --data '{"data":{"api_key":"api-key-from-deployer"}}' \
  "$BAO_ADDR/v1/secret/data/inventory/api" | jq '.data.version'
```

The answer is the new version number. The audit device records the request with the display name `userpass-deployer`, which is what the grader looks for.

## Step 4: Read it as a wrapped response

The `X-Vault-Wrap-TTL` header makes OpenBao keep the answer and return a wrapping token instead. `10m` gives the 600 seconds the task asks for:

```sh
WRAP_TOKEN="$(curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" -H "X-Vault-Wrap-TTL: 10m" \
  "$BAO_ADDR/v1/secret/data/inventory/api" | jq -r '.wrap_info.token')"
```

Check it without using it. Lookup needs no token and does not open the wrapping:

```sh
curl -s -X POST --data "{\"token\":\"$WRAP_TOKEN\"}" "$BAO_ADDR/v1/sys/wrapping/lookup" \
  | jq '.data | {creation_path, creation_ttl}'
```

`creation_path` is `secret/data/inventory/api` and `creation_ttl` is `600`.

## Step 5: Store the wrapping token for the receiver

```sh
kubectl -n api-demo create secret generic handover --from-literal=wrapping-token="$WRAP_TOKEN"
```

If the Secret already exists from an earlier try, delete it first with `kubectl -n api-demo delete secret handover`.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

The grader checks the token with `sys/wrapping/lookup` only, so submitting several times does not use it up. It fails if the token is unknown, which happens when it was unwrapped or when its 10 minutes ran out; then repeat steps 4 and 5.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Write the secret with the root token | It works, but the audit log shows `root`, and the handover is no longer traceable to the person responsible |
| Unwrap the token to see that it works | The token is used up; the receiver gets an error and must treat the key as leaked |
| Store the API key itself in the Kubernetes Secret | Anyone who can read Secrets in `api-demo` has the key, and nobody can tell |
| Wrap with `24h` "to give them time" | The grader asks for 600 seconds; a long TTL also gives an attacker more time |

## Practice on your own

- Unwrap the token from inside the `tester` pod as the receiver would, then submit again and read the grader's message.
- Wrap the AppRole `report` secret ID instead of a KV read: a `POST` to `auth/approle/role/report/secret-id` with `X-Vault-Wrap-TTL`.
