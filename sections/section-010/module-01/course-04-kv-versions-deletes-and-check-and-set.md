# KV Version 2 Versions, Deletes And Check-And-Set

KV version 2 keeps old versions of every secret. That helps when someone overwrites a value by mistake, and it surprises people who delete a secret and find it still there. This part shows how versions are numbered, what delete, undelete and destroy do, and how a check-and-set write stops two clients from overwriting each other.

The commands below need the port-forward from a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR` set to `http://openbao.localtest.me:8200`, and the lab-only root token in `ROOT_TOKEN`:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export ROOT_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

## Versions

Every write to a KV version 2 path creates a new version and keeps the old ones. Write the same secret twice and read the metadata, which lives at the `metadata/` path:

<!-- astrona:playground:renew -->

```sh
for color in blue green; do
  curl -s -X POST -H "X-Vault-Token: $ROOT_TOKEN" --data "{\"data\":{\"color\":\"$color\"}}" \
    "$BAO_ADDR/v1/secret/data/inventory/versions-demo" | jq '.data.version'
done
curl -s -H "X-Vault-Token: $ROOT_TOKEN" "$BAO_ADDR/v1/secret/metadata/inventory/versions-demo" \
  | jq '.data | {current_version, oldest_version, max_versions, cas_required}'
```

The two writes print the version numbers `1` and `2` if the secret did not exist before. The metadata shows `current_version` as `2`. `max_versions` of `0` means the engine's default, 10 versions, applies: when an eleventh version arrives, the oldest one is destroyed. A read without a version returns the current one. Add `?version=1` to the `data/` path to read an older one.

## Delete, undelete and destroy

KV version 2 has several operations that look like deleting, and they differ in whether the data can come back:

| Operation | Request | Effect |
| --- | --- | --- |
| Delete | `DELETE secret/data/<path>` or `POST secret/delete/<path>` with `{"versions":[1]}` | Marks versions as deleted. The data stays and can be restored |
| Undelete | `POST secret/undelete/<path>` with `{"versions":[1]}` | Restores marked versions |
| Destroy | `POST secret/destroy/<path>` with `{"versions":[1]}` | Removes the data of those versions for good |
| Delete metadata | `DELETE secret/metadata/<path>` | Removes every version and the metadata |

Delete the current version, read it, then undelete it:

```sh
curl -s -o /dev/null -w 'delete: HTTP %{http_code}\n' -X DELETE -H "X-Vault-Token: $ROOT_TOKEN" \
  "$BAO_ADDR/v1/secret/data/inventory/versions-demo"
curl -s -w '\nread: HTTP %{http_code}\n' -H "X-Vault-Token: $ROOT_TOKEN" \
  "$BAO_ADDR/v1/secret/data/inventory/versions-demo"
curl -s -o /dev/null -w 'undelete: HTTP %{http_code}\n' -X POST -H "X-Vault-Token: $ROOT_TOKEN" \
  --data '{"versions":[2]}' "$BAO_ADDR/v1/secret/undelete/inventory/versions-demo"
```

The delete answers `204`. The read answers `404`, and the body has `data` as `null` and `metadata` with a `deletion_time`. The undelete answers `204` and the next read works again. Because delete and undelete are separate capabilities, a policy can let a client delete versions and still stop it from destroying them.

## Check-and-set

Two clients that read a secret, change it and write it back can overwrite each other's change. The check-and-set option (`cas`) prevents that. The writer sends the version it read inside `options`, and OpenBao accepts the write only if that is still the current version:

```sh
curl -s -w '\nHTTP %{http_code}\n' -X POST -H "X-Vault-Token: $ROOT_TOKEN" \
  --data '{"options":{"cas":1},"data":{"color":"red"}}' \
  "$BAO_ADDR/v1/secret/data/inventory/versions-demo"
```

The current version is `2`, so this write is refused with status `400` and an error about the check-and-set parameter. Send `"cas":2` and it works. A `cas` of `0` means "write only if the secret does not exist". The metadata field `cas_required` makes the option mandatory for every write to a path, and `max_versions` changes how many versions are kept. Both are set with a `POST` to the `metadata/` path:

```sh
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X POST -H "X-Vault-Token: $ROOT_TOKEN" \
  --data '{"max_versions":3,"cas_required":false}' "$BAO_ADDR/v1/secret/metadata/inventory/versions-demo"
```

You can now read old versions, tell delete from destroy, and protect a shared secret with check-and-set. When a client, an agent template or a proxy reads KV, it reads the current version unless it asks for another.

## Common pitfalls

> [!WARNING]
> - **Thinking a delete removes the data.** It marks the version. Only destroy removes it.
> - **Reading a deleted secret and treating `404` as "never existed".** The metadata tells the difference.
> - **Writing without `cas` when two jobs update the same secret.** The last write wins and the other change is lost.
> - **Leaving `max_versions` at its default for a secret that changes every minute.** Old versions disappear faster than you expect.
