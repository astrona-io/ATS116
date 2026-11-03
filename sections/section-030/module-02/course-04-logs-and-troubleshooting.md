# Logs And Troubleshooting

When the application gets an error from the proxy, there are four places to look: the application's answer, the proxy's log, the proxy's configuration and OpenBao itself. This part is a checklist that sends you to the right one from the symptom.

## Read the answer first

The application's answer says who refused the request. Call the proxy from inside the pod, so you see the proxy's own answer without the application in between:

```sh
kubectl -n proxy-demo exec deploy/inventory -c app -- \
  wget -S -qO- http://127.0.0.1:8100/v1/secret/data/inventory/config
```

`wget -S` prints the response headers, including the status line. A response from OpenBao has a JSON body with an `errors` list. A response from `nginx` has an HTML body.

## Symptoms and causes

| Symptom | Likely cause | Where to look |
| --- | --- | --- |
| `502 Bad Gateway` from `nginx` | The proxy container is not running or is not listening on the address `nginx` uses | `kubectl -n proxy-demo get pods`, then the proxy's log |
| Connection refused to `127.0.0.1:8100` | The proxy has not finished starting, or the listener address differs | The `listener` stanza and the proxy's log |
| `403 permission denied` on a path you expect to work | The proxy's token lacks the policy, or a caller's token won because `use_auto_auth_token` is `true` | `auth/token/lookup-self` through the proxy, then the policy |
| `403 permission denied` on every path | The proxy's login failed, so it has no token, and the request had none | The proxy's log, then the Kubernetes auth role |
| `404` with an empty body or `no handler for route` | A wrong path, for example a KV version 2 path without `data/` | The request path |
| The request hangs and then fails | The `vault` address is wrong or OpenBao is unreachable | The `vault` stanza and the proxy's log |
| The request is rejected before it reaches OpenBao | `require_request_header` is on and the header is missing | The listener stanza |

## The proxy's log

```sh
kubectl -n proxy-demo logs deploy/inventory -c proxy | tail -n 30
```

At the start the proxy logs its configuration phases and the listener it opened. A failed login logs an error from the auth handler and then a back-off. A successful login logs that the authentication was successful. Start the proxy with `-log-level=debug` for the detail of each request. Remove the flag again afterwards. Debug logs are large and can contain more than you want to keep.

## Check the role from OpenBao

When the login fails, compare the role with the service account. With the root token set in your shell:

```sh
bao read auth/kubernetes/role/inventory-proxy
kubectl -n proxy-demo get serviceaccount
```

The names and the namespace in the role's `bound_service_account_names` and `bound_service_account_namespaces` must match the service account the pod runs as. A policy name that does not exist is stored without error and grants nothing.

## One change at a time

Change one thing, restart the pod, and repeat the failing request. The proxy reads its configuration at start, so a change that is not followed by a restart changes nothing. A second change made on a guess makes the first one impossible to judge.

## Try it

1. Change the role in `auto_auth` to a name that does not exist, restart, and read the log. Call `/config`. The answer is an error from OpenBao.
2. Restore the role name and restart.
3. Remove `inventory-reader` from the role with `bao write auth/kubernetes/role/inventory-proxy bound_service_account_names=inventory-proxy bound_service_account_namespaces=proxy-demo token_policies=default`, restart, and call `/config`. Which part refuses now?
4. Put the policy back with the same command and `token_policies=inventory-reader`.

## Common pitfalls

> [!WARNING]
> - **Testing only through the application.** Call the proxy from inside the pod to separate the app from the proxy.
> - **Reading the application's error as OpenBao's.** A `502` is from the web server, not from OpenBao.
> - **Changing the policy before reading the login log.** A refused login and a refused read look alike from the app.
> - **Forgetting the restart.** The old configuration is still running.
