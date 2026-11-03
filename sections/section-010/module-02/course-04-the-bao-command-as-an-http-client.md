# The bao Command As An HTTP Client

The `bao` command-line tool is an HTTP client. Every command builds a request, sends it to `/v1/`, and formats the JSON it gets back. When a command fails in a way you do not understand, the request underneath is the thing to look at. This part shows how to see that request and how the common commands map to paths.

The commands below need the port-forward from a second terminal, `BAO_ADDR` set to `http://openbao.localtest.me:8200`, and the `bao` command on your machine.

## Seeing the request

The flag `-output-curl-string` makes `bao` print the `curl` command it would run instead of sending it. Log in with the root token first, then print the command for a read:

<!-- astrona:playground:renew -->

```sh
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
bao kv get -output-curl-string secret/inventory/config
```

The printed command is a `curl` call to `$BAO_ADDR/v1/secret/data/inventory/config` with the `X-Vault-Token` header. `bao kv get` added the `data/` for you, because it knows the mount is KV version 2. The flag works on every command, so it is the quickest way to learn the path and the body of any operation.

## Common commands and their requests

Each command is a method and a path. The table shows the ones used most:

| Command | Request |
| --- | --- |
| `bao read auth/kubernetes/role/inventory-agent` | `GET /v1/auth/kubernetes/role/inventory-agent` |
| `bao write auth/userpass/users/deployer password=...` | `POST` or `PUT` with the pairs as a JSON body |
| `bao list secret/metadata/inventory` | `LIST` (or `GET ?list=true`) |
| `bao delete secret/data/inventory/old` | `DELETE` |
| `bao token lookup` | `GET /v1/auth/token/lookup-self` |
| `bao status` | `GET /v1/sys/seal-status` and `sys/health` |

`bao read`, `bao write` and `bao list` work on any path of any engine. The `bao kv` commands exist only for KV: they add `data/` or `metadata/`, and `bao kv put` wraps your pairs in the `data` object. Compare the two ways of writing:

```sh
bao write -output-curl-string secret/data/inventory/notes data=owner=inventory
bao kv put -output-curl-string secret/inventory/notes owner=inventory
```

In the first command you must give the full path with `data/` yourself, and the pairs do not form the nested `data` object that KV version 2 expects. The second command gives the correct request from a shorter command, which is why `bao kv` exists.

## Output formats and fields

By default `bao` prints a table. Two options make the output usable in scripts. `-format=json` prints the whole response, the same JSON `curl` would show. `-field=<name>` prints one field of `data` as plain text:

```sh
bao kv get -format=json secret/inventory/config | jq '.data.data'
bao kv get -field=db_host secret/inventory/config
```

The first prints the three fields as JSON and the second prints only the host name. For KV version 2, `-field` reads from the secret's own fields, not from the metadata.

## Finding out how a path works

If you do not know which fields a path takes, ask the server. The command `bao path-help` prints the help text of a path, with its fields and operations, from the engine itself:

```sh
bao path-help auth/token/create
```

The output lists the parameters you saw as JSON fields earlier, such as `policies`, `ttl` and `num_uses`. Together with `-output-curl-string`, this lets you build a request for any endpoint without searching for documentation.

Two environment variables control the connection. `BAO_ADDR` is the server address and `BAO_TOKEN` is the token the command sends. If a command prints `permission denied`, check `bao token lookup` first: an old `BAO_TOKEN` in the shell is a common cause.

You now have all the moves for working with the API: a request by hand, the same request from `bao`, and the request behind any command.

## Common pitfalls

> [!WARNING]
> - **Using `bao write` on KV version 2 without `data/` and the `data` object.** The write goes to the wrong place or fails.
> - **Forgetting `BAO_ADDR`.** The command talks to its default address, not to your port-forward.
> - **Pasting the printed `curl` command into a shared place.** It contains your token.
> - **Parsing the table output.** Use `-format=json` or `-field` in scripts.
