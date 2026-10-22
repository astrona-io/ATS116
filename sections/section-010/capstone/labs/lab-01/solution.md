# Solution: Repair A Script That Calls The OpenBao API

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass.

The grader creates its own Job from the CronJob, waits for it to complete, and checks the report lines. It also checks that the script still logs in with AppRole and holds no token, and that the AppRole still grants `inventory-lister`.

## Step 1: See what the script does

Read the script and a failed run:

```sh
kubectl -n apicapstone get configmap report-script -o jsonpath='{.data.report\.sh}'
kubectl -n apicapstone create job --from=cronjob/inventory-report report-run-1
kubectl -n apicapstone logs job/report-run-1
```

The script makes three kinds of request: a login, a list and a read per key. Each one has a bug. Reproduce them one at a time from the `tester` pod, which has the same tools as the Job.

## Step 2: The login reads the token from the wrong field

Log in the way the script does, but print the whole answer:

```sh
ROLE_ID="$(kubectl -n apicapstone get secret report-approle -o jsonpath='{.data.role-id}' | base64 -d)"
SECRET_ID="$(kubectl -n apicapstone get secret report-approle -o jsonpath='{.data.secret-id}' | base64 -d)"
kubectl -n clients exec deploy/tester -- curl -s -X POST \
  --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  http://openbao.openbao.svc:8200/v1/auth/approle/login | jq '{data, auth: .auth.client_token}'
```

`data` is `null`; the token is in `auth.client_token`. The script reads `.data.client_token`, so every later request carries the header `X-Vault-Token: null` and gets `403`. The secret ID is single-use only if the role says so; this role allows reuse, so logging in again is harmless.

## Step 3: The list is a plain GET

The script sends `GET secret/metadata/inventory`. That reads the metadata of a secret named `inventory`, which does not exist, so the answer is `404` and `jq` finds no `keys`. A list needs the `LIST` method (or `?list=true`):

```sh
curl -s -X LIST -H "X-Vault-Token: $TOKEN" "$API/secret/metadata/inventory"
```

## Step 4: The reads leave out data/

The script reads `secret/inventory/$key`. On a KV version 2 mount the values live under `secret/data/...`, so the path must be `secret/data/inventory/$key`. Without `data/` OpenBao does not return the secret.

## Step 5: Apply the fixed script

Save this as `report.sh`:

```sh
#!/bin/sh
# Lists every secret under secret/inventory and prints its fields.
set -eu
API="http://openbao.openbao.svc:8200/v1"
ROLE_ID="$(cat /etc/approle/role-id)"
SECRET_ID="$(cat /etc/approle/secret-id)"

LOGIN="$(curl -s -X POST --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" "$API/auth/approle/login")"
TOKEN="$(printf '%s' "$LOGIN" | jq -r '.auth.client_token')"

KEYS="$(curl -s -X LIST -H "X-Vault-Token: $TOKEN" "$API/secret/metadata/inventory" | jq -r '.data.keys[]')"
for key in $KEYS; do
  FIELDS="$(curl -s -H "X-Vault-Token: $TOKEN" "$API/secret/data/inventory/$key" | jq -c '.data.data')"
  echo "$key: $FIELDS"
done
echo "REPORT OK"
```

Replace the ConfigMap with it:

```sh
kubectl -n apicapstone create configmap report-script --from-file=report.sh \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then check the result with a new run:

```sh
kubectl -n apicapstone create job --from=cronjob/inventory-report report-run-2
kubectl -n apicapstone wait --for=condition=complete job/report-run-2 --timeout=120s
kubectl -n apicapstone logs job/report-run-2
```

The log has one line for `api`, `billing` and `config` with their fields, and `REPORT OK`.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put the root token into the script | The report works, and anyone who can read the ConfigMap now holds full control of OpenBao. The grader refuses it |
| Give the AppRole a policy with `*` | The bug was never the policy; `403` came from the `null` token |
| Hard-code the three keys instead of listing | The report silently misses every secret added later |
