# AppRole Roles And Secret IDs

A program outside Kubernetes needs two things to log in with AppRole, and OpenBao wants them to arrive by different paths. This part reads a role, shows what the role ID and the secret ID are, and sets the limits that stop a leaked secret ID from being useful for long.

The commands below need the port-forward from a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

## The role

AppRole is an auth method for applications. A role is a named set of rules: which policies a login gets, how long the token lives and who may use the role. Read the role `nightly`:

<!-- astrona:playground:renew -->

```sh
bao read auth/approle/role/nightly
```

The fields to look at are `token_policies` (`inventory-reader`), `token_ttl`, `token_max_ttl`, `secret_id_ttl`, `secret_id_num_uses`, `bind_secret_id` and the two CIDR lists. A CIDR list limits the source network addresses, in Classless Inter-Domain Routing notation such as `10.0.0.0/8`. `token_bound_cidrs` limits where the token works, and `secret_id_bound_cidrs` limits where the secret ID may be used.

## Role ID and secret ID

A login sends two values. The role ID names the role. It is not secret on its own, and a deployment can put it in the image or in a ConfigMap. The secret ID is the password. It is generated on request and can have its own lifetime and use limit. Read the role ID and create a secret ID:

```sh
ROLE_ID="$(bao read -field=role_id auth/approle/role/nightly/role-id)"
SECRET_ID="$(bao write -f -field=secret_id auth/approle/role/nightly/secret-id)"
```

The `-f` flag sends the request with no fields, because the endpoint needs none. Log in with both values over HTTP:

```sh
curl -s -X POST --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  "$BAO_ADDR/v1/auth/approle/login" | jq '.auth | {policies, lease_duration}'
```

The answer holds a token in `auth.client_token` with the policies of the role. The split exists so that no single place holds both values: the role ID is part of the deployment, and the secret ID is delivered at run time by a trusted system, such as a pipeline.

## Limits that matter

Three role settings decide how dangerous a stolen secret ID is:

- `secret_id_ttl` is how long a secret ID stays valid after it is created. `0` means it never expires.
- `secret_id_num_uses` is how many logins one secret ID can make. `1` means one login. `0` means unlimited.
- `secret_id_bound_cidrs` limits the addresses that may log in with it.

Change the role so that each secret ID works for ten minutes and one login, then prove that the second login fails:

```sh
bao write auth/approle/role/nightly token_policies=inventory-reader secret_id_ttl=10m secret_id_num_uses=1
SECRET_ID="$(bao write -f -field=secret_id auth/approle/role/nightly/secret-id)"
for attempt in 1 2; do
  curl -s -o /dev/null -w "login $attempt: HTTP %{http_code}\n" -X POST \
    --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" "$BAO_ADDR/v1/auth/approle/login"
done
```

The first login returns `200` and the second returns `400` with the error `invalid secret id`. A one-use secret ID turns a leak into an alarm: if the program finds its secret ID already used, someone else got there first.

## Managing secret IDs

A secret ID has an accessor, a second identifier that lets an administrator look it up or destroy it without knowing the secret ID. The response of the create request includes `secret_id_accessor`. List the accessors of a role with `LIST` on `auth/approle/role/nightly/secret-id`, look one up with a `POST` to `secret-id-accessor/lookup`, and destroy it with `secret-id-accessor/destroy`. A role with `bind_secret_id` set to `false` accepts a login with the role ID alone, which is only safe together with a tight CIDR list.

You can now explain what a role, a role ID and a secret ID are, and limit a secret ID in time, uses and place. The open question is how the secret ID gets to the agent without showing up in a log or a ticket on the way.

## Common pitfalls

> [!WARNING]
> - **A secret ID with `secret_id_ttl=0` and `secret_id_num_uses=0`.** It works forever, as often as anyone sends it.
> - **Putting the secret ID in the same ConfigMap as the role ID.** Then one read of the ConfigMap gives the full login.
> - **Writing to the role without repeating its other settings.** An update with only some fields can reset settings you wanted to keep. Read the role first.
> - **Confusing `token_ttl` with `secret_id_ttl`.** The first is the life of the token the login returns; the second is the life of the secret ID before the login.
