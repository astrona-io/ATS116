# Several Secrets, Several Files

A pod often needs more than one secret: a database password, an API token, a certificate. The injector handles this with one set of annotations per secret. The part of the annotation name after the last hyphen group is the **unique name**, and it ties the annotations of one secret together. This part shows how the unique name, the file name and the directory relate.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## The unique name

```yaml
vault.hashicorp.com/agent-inject-secret-config.env: "secret/data/inventory/config"
vault.hashicorp.com/agent-inject-template-config.env: "..."
```

In `agent-inject-secret-config.env`, the unique name is `config.env`. The value is the secret's path. By default the injector writes the secret to a file with the unique name, here `/vault/secrets/config.env`. Other annotations that start with `agent-inject-` and end with `-config.env` belong to the same secret.

A second secret needs a second unique name:

```yaml
vault.hashicorp.com/agent-inject-secret-api: "secret/data/inventory/api"
```

The two unique names, `config.env` and `api`, must be different. If two annotations use the same unique name, one of them is lost, because annotations are a map and a key can appear only once.

## Choosing the file name

The unique name can be a file name, but it is also used inside an annotation key, where some characters are awkward. Keep the unique name simple and set the file name separately:

```yaml
vault.hashicorp.com/agent-inject-secret-api: "secret/data/inventory/api"
vault.hashicorp.com/agent-inject-file-api: "api.json"
```

`agent-inject-file-<name>` sets the file name, relative to the secrets directory.

## Choosing the directory

All files go to `/vault/secrets` by default, in an in-memory volume shared by the containers. Two annotations change the directory:

| Annotation | Effect |
| --- | --- |
| `vault.hashicorp.com/secret-volume-path` | The directory for every secret of the pod |
| `vault.hashicorp.com/secret-volume-path-<name>` | The directory for one secret |

The application must read the files from the path you choose. The `nginx` configuration of the playground reads `/vault/secrets`, so changing the path in the pod without changing the application breaks it. A relative `agent-inject-file` can include a sub-directory name.

## The secret path

The value of `agent-inject-secret-<name>` is the API path of the secret, so a KV version 2 secret needs `data/` in it: `secret/data/inventory/api`. The injector does not add it for you in the annotation. A policy must allow the same path: `inventory-reader` allows `secret/data/inventory/*`, which covers both secrets of the playground.

## Which containers can see the files

The shared volume is mounted in every container of the pod. `vault.hashicorp.com/agent-inject-containers` limits the mount to the containers you name, as a comma-separated list. Use it to keep secrets away from sidecars that do not need them, such as a log shipper.

## Try it

1. In the playground, call `/api` from the `tester` pod. It answers `404`, because no file exists yet.
2. Add the annotations for the secret `api` with the file name `api.json` to the pod template, with `kubectl -n inventory edit deployment inventory`. Skip the template for now.
3. Wait for the new pod and run `kubectl -n inventory exec deploy/inventory -c app -- ls /vault/secrets`. Two files exist.
4. Read `api.json` with `kubectl -n inventory exec deploy/inventory -c app -- cat /vault/secrets/api.json`. It holds the default output, which is not JSON. The next part explains why and fixes it.

## Common pitfalls

> [!WARNING]
> - **Reusing a unique name.** The second annotation replaces the first, and one secret never appears.
> - **Leaving out `data/` for KV version 2.** The agent asks for a path that does not exist and the pod stays in `Init:0/1`.
> - **Changing the directory and not the application.** The file is written where nothing reads it.
> - **Putting a character in the unique name that is not allowed in annotation keys.** Use letters, digits, dots and hyphens.
