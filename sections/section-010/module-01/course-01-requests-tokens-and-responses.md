# Requests, Tokens And Responses

When the `bao` command-line tool or an agent fails, it usually prints a short message such as `permission denied`. The full story is in the HTTP request it sent and the response it got. This part shows you how to send those requests yourself and how to read every field of the answer, so that a short message turns into a clear cause.

## Reaching the API

The OpenBao HTTP API is the REST interface the server offers under the path prefix `/v1/`. REST means each path names a thing, and the HTTP method says what to do with it: `GET` reads, `POST` or `PUT` writes, `DELETE` removes. Every client in this course uses this API underneath.

Your machine reaches OpenBao through a port-forward. Start it in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n openbao port-forward svc/openbao 8200:8200
```

Back in your first terminal, set the address that every command on this page uses. The name `openbao.localtest.me` points at your own machine, so the port-forward answers it:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
```

The listener in this playground has no TLS (Transport Layer Security, the encryption HTTPS adds). That is lab-only: a real OpenBao server always uses `https://`.

## Requests that need no token

A few paths answer without a token, because a load balancer or an operator must be able to check the server before anyone can log in. Ask for the health of the server:

```sh
curl -s "$BAO_ADDR/v1/sys/health" | jq
```

The answer is a JSON object. `initialized` and `sealed` tell you the server's state, and `version` shows `2.7.1`. The HTTP status code carries meaning too: `sys/health` returns `200` for an unsealed, active server, `503` for a sealed one and `501` for one that is not initialized. A load balancer only looks at that code.

Now ask for something that needs a token, without one:

```sh
curl -s -w '\nHTTP %{http_code}\n' "$BAO_ADDR/v1/secret/data/inventory/config"
```

OpenBao answers with status `403` and a body with one field, `errors`, a list of messages. Here the list says `permission denied`. A request without a token is treated exactly like a request with a token that has no rights.

## Sending a token

OpenBao reads the token from the `X-Vault-Token` request header. The header name still says `Vault` because OpenBao started as a fork of HashiCorp Vault and keeps the old names, so existing tools keep working. The standard header `Authorization: Bearer <token>` works as well.

This playground keeps the lab-only root token in a Kubernetes Secret. Load it into your shell:

```sh
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

A real installation never stores the root token in a Kubernetes Secret, and it revokes the root token after setup. Send the same request again, this time with the header:

```sh
curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/inventory/config" | jq
```

This time the status is `200` and the body holds the secret. The `bao` CLI sends exactly this request when you run `bao kv get secret/inventory/config`, and it reads the token from the same `BAO_TOKEN` variable.

## Reading a response

Every successful response has the same outer fields, and each one tells you something specific. Some are empty for one kind of request and filled for another, so learn them once:

| Field | What it holds |
| --- | --- |
| `request_id` | An identifier for this request; the audit log uses the same one |
| `data` | The answer itself. For a KV version 2 read it holds `data` (your fields) and `metadata` (the version and its times) |
| `lease_id`, `lease_duration`, `renewable` | The lease of a dynamic secret: an identifier, how long it is valid in seconds, and whether it can be extended |
| `auth` | Filled only by a login: the new token in `client_token`, its `policies`, and its own `lease_duration` |
| `wrap_info` | Filled only when the response was wrapped: the wrapping token and its time to live |
| `warnings` | Messages that did not stop the request, for example a deprecated field |

Pick one field out with `jq`. This prints only your fields, the inner `data` of the outer `data`:

```sh
curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/inventory/config" | jq '.data.data'
```

The double `data` confuses everyone the first time. The outer one belongs to the API, the inner one to the KV version 2 secrets engine, which puts your fields next to its own `metadata`.

## Reading an error

An error has no `data`, only a status code and the `errors` list. The code tells you the class of problem before you read a word:

| Status | What it means |
| --- | --- |
| `400` | The request is malformed, for example a missing field or bad JSON |
| `403` | The token is missing, invalid, expired, or its policies do not allow this path and operation |
| `404` | Nothing exists at this path. A `LIST` with no results also returns `404` |
| `405` | The path does not support this method |
| `503` | OpenBao is sealed or not ready |

A path that does not exist, and a path the token may not read, are different problems with different fixes. Ask for a secret that is not there:

```sh
curl -s -w '\nHTTP %{http_code}\n' -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/inventory/missing"
```

The root token may read every path, so the `404` here can only mean the secret does not exist. With a normal token, a `403` on the same path would point at its policy instead.

You can now send a request with or without a token, read each field of the answer, and tell from the status code whether to look at the path, the token or the server. All of that was done with the root token, which no application should ever hold. The open question is how a person or a program gets its own, limited token.

## Common pitfalls

> [!WARNING]
> - **Reading `.data` and expecting your fields.** For KV version 2 your fields are in `.data.data`; `.data.metadata` holds the version.
> - **Treating every `403` as a policy problem.** A missing, mistyped or expired token also gives `403`. Check the token first with `bao token lookup`.
> - **Forgetting the port-forward.** `curl` then fails to connect at all, which is not an OpenBao error. Start it again in the second terminal.
> - **Using the root token in scripts.** It is fine for this playground, and never acceptable in a real application.
