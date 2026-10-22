# Logging In, Reading, Writing And Listing

An application should never use the root token. It logs in with its own identity, gets a token with only the policies it needs, and uses that token for its requests. This part does that over HTTP twice: once as a person with userpass and once as a program with AppRole. Then it uses the tokens to write, read and list KV version 2 secrets, where the paths are not quite what you type into the CLI.

The commands below need the port-forward from the second terminal and `BAO_ADDR` set to `http://openbao.localtest.me:8200`.

## Logging in as a person

The userpass auth method checks a user name and a password that OpenBao stores itself. Logging in is a `POST` to `auth/userpass/login/<user name>` with the password in the body, and it needs no token. Log in as the lab-only user `deployer` and keep the token from the response:

<!-- astrona:playground:renew -->

```sh
DEPLOYER_TOKEN="$(curl -s -X POST --data '{"password":"deployer-password"}' \
  "$BAO_ADDR/v1/auth/userpass/login/deployer" | jq -r '.auth.client_token')"
echo "$DEPLOYER_TOKEN"
```

A login fills the `auth` field of the response, not `data`. `auth.client_token` is the new token, `auth.policies` lists `default` and `inventory-writer`, and `auth.lease_duration` is how many seconds the token lives. The `default` policy is added to every token; it lets a token look itself up and renew itself.

## Writing and reading a KV version 2 secret

KV version 2 is the secrets engine mounted at `secret/` here. It keeps every version of a secret, so its API splits each secret into two paths: `secret/data/<path>` for the values and `secret/metadata/<path>` for the version history. The CLI hides this; `bao kv put secret/inventory/notes` writes to `secret/data/inventory/notes`. Over HTTP you type the full path, and your fields go inside a `data` object:

```sh
curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" -X POST \
  --data '{"data":{"owner":"inventory-team","pager":"inventory-oncall"}}' \
  "$BAO_ADDR/v1/secret/data/inventory/notes" | jq '.data'
```

The answer to a write is metadata only: `version` is `1` and `created_time` is now. Write it again with any change and `version` becomes `2`. Read the secret back with the same token:

```sh
curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" \
  "$BAO_ADDR/v1/secret/data/inventory/notes" | jq '{fields: .data.data, version: .data.metadata.version}'
```

The `inventory-writer` policy allows `create`, `read` and `update` on `secret/data/inventory/*`, so all of this works. The same request to a path outside `secret/data/inventory/` would return `403`.

## Listing keys

Listing returns the names under a path, not their values, and it uses the metadata path. The API documents it as the `LIST` method, which `curl` can send with `-X LIST`:

```sh
curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" -X LIST \
  "$BAO_ADDR/v1/secret/metadata/inventory" | jq '.data.keys'
```

The answer is a list of names: `api`, `billing`, `config` and `notes`. Some HTTP clients cannot send a method called `LIST`. For them, a `GET` with the query parameter `?list=true` does the same thing:

```sh
curl -s -H "X-Vault-Token: $DEPLOYER_TOKEN" \
  "$BAO_ADDR/v1/secret/metadata/inventory?list=true" | jq '.data.keys'
```

Without `-X LIST` or `?list=true`, a `GET` on `secret/metadata/inventory` reads the metadata of a secret named `inventory`. No such secret exists, so you get `404`, and that `404` is a classic bug in scripts.

## Logging in as a program

A program has no password to type. The AppRole auth method gives it two values instead: a role ID, which is like a user name and not secret, and a secret ID, which is like a password. An administrator, or a deployment pipeline, hands both to the program. Fetch them for the role `report` with the root token, the way such a pipeline would:

```sh
ROOT_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
ROLE_ID="$(curl -s -H "X-Vault-Token: $ROOT_TOKEN" "$BAO_ADDR/v1/auth/approle/role/report/role-id" | jq -r '.data.role_id')"
SECRET_ID="$(curl -s -H "X-Vault-Token: $ROOT_TOKEN" -X POST "$BAO_ADDR/v1/auth/approle/role/report/secret-id" | jq -r '.data.secret_id')"
```

Now log in as the program and try a write that its policy does not allow:

```sh
REPORT_TOKEN="$(curl -s -X POST --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  "$BAO_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')"
curl -s -w '\nHTTP %{http_code}\n' -H "X-Vault-Token: $REPORT_TOKEN" -X POST \
  --data '{"data":{"owner":"someone-else"}}' "$BAO_ADDR/v1/secret/data/inventory/notes"
```

The login works the same way as userpass and fills `auth.client_token`. The write returns `403` with `permission denied`, because the `inventory-lister` policy allows only `read` on the secrets and `list` on their names. That `403` is OpenBao doing its job: the token works, its policy does not allow this operation.

You can now log in over HTTP as a person and as a program, write and read KV version 2 secrets through their `data/` paths, and list their names through the `metadata/` path. Every value so far travelled in plain JSON to whoever sent the request. The open question is how to hand a secret to someone else without it being readable on the way.

## Common pitfalls

> [!WARNING]
> - **Reading the token from `.data` after a login.** Logins fill `.auth.client_token`; `.data` is empty, so `jq` prints `null` and the next request fails with `403`.
> - **Leaving out `data/` in a KV version 2 path.** `secret/inventory/notes` is the CLI's short form. Over HTTP the path is `secret/data/inventory/notes`.
> - **Listing with a plain `GET`.** Use `-X LIST` or `?list=true` on the `metadata/` path, or you read a secret that does not exist.
> - **Writing fields at the top level of the body.** KV version 2 expects them inside `{"data": {...}}`.
