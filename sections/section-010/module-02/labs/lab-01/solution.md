# Solution: Issue A Limited Token For A Reporting Job

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader looks the token up with the root token and checks three facts: its policies, its creation TTL and its remaining uses.

## Step 1: Reach OpenBao

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n openbao port-forward svc/openbao 8200:8200
```

In your first terminal, set the address and load the lab-only root token:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export ROOT_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

## Step 2: Create the token

A create request names the policies, the TTL and the use limit. The new token is in `auth.client_token`:

```sh
REPORT_TOKEN="$(curl -s -X POST -H "X-Vault-Token: $ROOT_TOKEN" \
  --data '{"policies":["inventory-lister"],"ttl":"15m","num_uses":5,"display_name":"report-job"}' \
  "$BAO_ADDR/v1/auth/token/create" | jq -r '.auth.client_token')"
```

If `REPORT_TOKEN` is empty, send the request without `| jq ...` and read the `errors` list.

## Step 3: Check it with the root token

Looking the token up with its own value would use one of its five uses. Send the token in the body of a request made with the root token instead:

```sh
curl -s -X POST -H "X-Vault-Token: $ROOT_TOKEN" --data "{\"token\":\"$REPORT_TOKEN\"}" \
  "$BAO_ADDR/v1/auth/token/lookup" | jq '.data | {policies, creation_ttl, num_uses}'
```

`policies` is `default` and `inventory-lister`, `creation_ttl` is `900` and `num_uses` is `5`.

## Step 4: Store the token for the job

```sh
kubectl -n api-demo create secret generic report-token --from-literal=token="$REPORT_TOKEN"
```

If the Secret already exists from an earlier try, delete it first with `kubectl -n api-demo delete secret report-token`.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

The grader looks the token up with the root token, so submitting several times does not use it up.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Store the root token in the Secret | The job can do everything, and the check for the policy `root` fails |
| Test the token with `lookup-self` | Each request uses one of the five uses, so `num_uses` is no longer 5 |
| Create the token without `num_uses` | The use limit is `0`, which means unlimited |
| Use `ttl` of `15` | OpenBao reads it as 15 seconds, not minutes; write `15m` |

## Practice on your own

- Use the token for a `LIST` of `secret/metadata/inventory` and watch `num_uses` go down by looking it up with the root token.
- Create the same token with `"type":"batch"` and read what changes in the answer.
