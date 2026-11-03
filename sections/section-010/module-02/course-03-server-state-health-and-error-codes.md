# Server State, Health And Error Codes

Sometimes the token and the policy are fine and the request still fails, because the server is sealed, not initialized or not the active node. A client that cannot tell these cases apart retries forever or gives up too early. This part reads the server's own endpoints and the status codes of failed requests.

The commands below need the port-forward from a second terminal and `BAO_ADDR` set to `http://openbao.localtest.me:8200`.

## The health endpoint

The endpoint `sys/health` needs no token and tells load balancers and probes whether a node can serve requests. It reports the answer in the HTTP status code and repeats it in the body:

<!-- astrona:playground:renew -->

```sh
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "$BAO_ADDR/v1/sys/health"
curl -s "$BAO_ADDR/v1/sys/health" | jq '{initialized, sealed, standby, version}'
```

The first command prints `200`: the node is initialized, unsealed and the active node. The body shows `initialized` as `true`, `sealed` as `false` and `standby` as `false`. The other status codes mean:

| Status | Meaning |
| --- | --- |
| `200` | Initialized, unsealed and active |
| `429` | Unsealed, but a standby node; it forwards requests to the active node |
| `501` | Not initialized |
| `503` | Sealed |

A health check can change these codes with query parameters. For example, `?standbyok=true` makes a standby node answer `200`, and `?sealedcode=200` changes the code for a sealed node. A Kubernetes probe usually sets the ones that match what it should treat as ready.

## Seal status and leader

Two more endpoints need no token. `sys/seal-status` shows whether the node is sealed, how many key shares exist, and how many are needed to unseal. `sys/leader` shows whether this node is the leader and where the leader is. Read them both:

```sh
curl -s "$BAO_ADDR/v1/sys/seal-status" | jq '{sealed, t, n, version, storage_type}'
curl -s "$BAO_ADDR/v1/sys/leader" | jq
```

`t` is the threshold of key shares and `n` the number of shares; the playground uses one of one. `storage_type` is `raft`. A sealed server answers almost every other request with status `503`, so this is the first thing to check when many clients fail at once.

## Reading an error

A failed request has a status code and a JSON body with an `errors` list. The code points at the cause:

| Status | Usual cause |
| --- | --- |
| `400` | The request body or a parameter is wrong |
| `403` | The token is missing, expired, or lacks the capability |
| `404` | No such path, or a secret that has no value |
| `405` | The path exists, but not for this method |
| `429` | The node is a standby |
| `500` | An internal error; read the server log |
| `503` | Sealed, or the storage is not ready |

Produce three of them yourself:

```sh
curl -s -w '\nHTTP %{http_code}\n' "$BAO_ADDR/v1/secret/data/inventory/config"
curl -s -w '\nHTTP %{http_code}\n' -H "X-Vault-Token: $(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)" "$BAO_ADDR/v1/secret/data/inventory/missing"
curl -s -w '\nHTTP %{http_code}\n' -X DELETE "$BAO_ADDR/v1/sys/health"
```

The first is `403` because it has no token. The second is `404` with an empty `errors` list, because the path is valid but the secret does not exist. The third is `405`, because `sys/health` does not accept `DELETE`. A `404` with an empty list means "no data here"; a `404` with the error `unsupported path` means the mount does not exist.

## Standby nodes and retries

A cluster has one active node and any number of standby nodes. A request that reaches a standby node is forwarded to the active node, or answered with a redirect to it, depending on the cluster settings. A client library follows the redirect on its own; a hand-written client must not treat it as a failure. When the status is `5xx` or `429`, retry with a growing delay. When it is `4xx`, do not retry: the same request will fail the same way.

OpenBao also supports namespaces, which separate tenants inside one server. A client selects one with the `X-Vault-Namespace` header, or `BAO_NAMESPACE` for the `bao` command. A path that works in one namespace returns `404` or `403` in another, so check the header when a path that worked before suddenly fails.

You can now tell a server problem from a token problem by the endpoint and the status code. The remaining skill is moving between the `curl` request and the `bao` command that sends it.

## Common pitfalls

> [!WARNING]
> - **Using `sys/health` as a login test.** It needs no token, so it says nothing about your credentials.
> - **Retrying a `403`.** The same request keeps failing. Fix the token or the policy.
> - **Treating `404` as one cause.** Read the `errors` list: empty means no value, `unsupported path` means no mount.
> - **A readiness probe that rejects a standby node.** The default code is `429`, so set `standbyok` if standby nodes must count as ready.
