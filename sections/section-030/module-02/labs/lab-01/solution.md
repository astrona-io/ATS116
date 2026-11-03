# Solution: Make The Proxy Use Its Own Token

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks that `/config` returns the current secret, that a request with a made-up token gets the proxy's own identity, that the nginx configuration and app container are unchanged, that only the pod can reach the proxy, and that no token is stored.

## Step 1: See what the app gets

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config
kubectl -n proxy-demo exec deploy/inventory -c app -- \
  wget -qO- http://127.0.0.1:8100/v1/secret/data/inventory/config
```

The first command returns an error from OpenBao. The second sends no token, so the proxy adds its own, and it returns the secret. The proxy works. The difference is the header that nginx adds.

## Step 2: Read the proxy configuration

```sh
kubectl -n proxy-demo get configmap proxy-config -o jsonpath='{.data.proxy\.hcl}'
```

The `api_proxy` stanza says `use_auto_auth_token = true`. With `true` the proxy adds its token only to requests that have none, and forwards a request that already carries a token unchanged. The made-up token reaches OpenBao, and OpenBao refuses it.

## Step 3: Make the proxy always use its own token

Edit the ConfigMap with `kubectl -n proxy-demo edit configmap proxy-config` and change the stanza to:

```hcl
api_proxy {
  use_auto_auth_token = "force"
}
```

The value is the string `"force"`, in quotes. With `"force"` the proxy replaces any token on the request with its own.

## Step 4: Restart the pod and check

The proxy reads its configuration only at start:

```sh
kubectl -n proxy-demo rollout restart deployment/inventory
kubectl -n proxy-demo rollout status deployment/inventory
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config | jq '.data.data'
kubectl -n proxy-demo exec deploy/inventory -c app -- \
  wget -qO- --header 'X-Vault-Token: made-up-token' http://127.0.0.1:8100/v1/auth/token/lookup-self
```

The last command shows the proxy's own token with the policies `default` and `inventory-reader`, even though the request carried another token.

## Common mistakes

- Changing `nginx-conf` to remove the header. The task is to fix the proxy, not the app.
- Writing `use_auto_auth_token = force` without quotes. It must be the string `"force"`.
- Forgetting to restart the pod, so the old configuration is still running.
- Widening the policy to make the old token work.
