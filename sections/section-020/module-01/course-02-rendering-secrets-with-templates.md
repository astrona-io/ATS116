# Rendering Secrets With Templates

The application reads a plain configuration file with lines such as `DB_HOST=...`. The agent has a token that may read `secret/inventory/config`. A template connects the two: it says which secret to read and how to write its fields into the file. This part reads the template of the playground, proves the file follows a new secret version, and shows how a small mistake in a template quietly breaks the file.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## The file the application serves

Start from what the application sees. The `nginx` container serves `/etc/inventory/config.env` at `/config`; ask for it from the `tester` pod:

<!-- astrona:playground:renew -->

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
```

Three lines come back: `DB_HOST=postgres.inventory.svc`, `DB_USER=inventory` and `API_KEY=` followed by the current key. `nginx` read them from a file on the in-memory volume both containers share; the agent wrote that file, and `nginx` never talked to OpenBao.

## The template stanza

A `template` stanza names a `destination`, the file to write, and gives the template either inline in `contents` or from a file in `source`. This is the stanza in the playground:

```hcl
template {
  destination = "/etc/inventory/config.env"
  contents    = <<EOT
{{ with secret "secret/data/inventory/config" }}DB_HOST={{ .Data.data.db_host }}
DB_USER={{ .Data.data.db_user }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
EOT
}
```

The template language is Go's text templates with OpenBao functions added; OpenBao's fork of the consul-template project provides them. `{{ with secret "<path>" }}` reads one secret with the agent's token and makes its response the current value, written `.`, until `{{ end }}`. Write the full API path, `secret/data/...`, the same path a `curl` request and the policy use. The template engine notices a KV version 2 mount and adds `data/` itself if you leave it out, but the full path keeps the template, the policy and your debugging requests identical.

Inside `with`, `.Data` is the response's `data` field. For KV version 2 that holds the engine's own `data` and `metadata`, so your fields are at `.Data.data.<field>`. Everything outside `{{ }}` is copied into the file as it is, including the line breaks.

| Template piece | What it gives |
| --- | --- |
| `{{ with secret "secret/data/inventory/config" }}` | Reads the secret; skips the block if the read fails |
| `{{ .Data.data.db_host }}` | One field of a KV version 2 secret |
| `{{ .Data.metadata.version }}` | The version that was rendered |
| `{{ range $key, $value := .Data.data }}{{ $key }}={{ $value }}{{ end }}` | Every field, without naming them |

## When the agent renders again

The agent does not watch OpenBao for changes. It reads a secret again on a timer that depends on the kind of secret. A dynamic secret with a lease is read again before the lease runs out. A KV version 2 secret has no lease, so the agent reads it again every `static_secret_render_interval`, five minutes by default. This playground sets it to 15 seconds in the `template_config` stanza:

```hcl
template_config {
  static_secret_render_interval = "15s"
}
```

Write a new version of the secret and watch the file follow it:

```sh
bao kv patch secret/inventory/config api_key=changed-in-the-playground
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
```

`API_KEY` now shows the new value. The pod did not restart; check with `kubectl -n agent-demo get pods`, where the age and the restart count are unchanged. The agent wrote the file again, and `nginx` read the new file on the next request. An application that reads its file only at start needs a signal instead; the `command` option of a template runs a command after each render, for example to reload the application.

## When a template goes wrong

A template fails quietly from the application's point of view: the file is missing, or a line holds `<no value>` instead of a value. The agent's log is where the reason appears. Break the template on purpose, the way people often do: edit the ConfigMap and change `.Data.data.db_host` to `.Data.db_host`:

```sh
kubectl -n agent-demo edit configmap agent-config
kubectl -n agent-demo rollout restart deployment/inventory
```

After the new pod starts, ask for `/config` again from the `tester` pod. The line now reads `DB_HOST=<no value>`: the agent read the secret, but `.Data` has no field `db_host`, because KV version 2 nests your fields one level deeper under `.Data.data`. Nothing failed, so the log stays quiet. Set `error_on_missing_key = true` in the `template` stanza to turn a missing field into an error in the log instead of `<no value>` in the file. Put `.Data.data.db_host` back and restart the Deployment again before you go on.

Two other mistakes stop the file from appearing at all, and both show up in the agent's log (`kubectl -n agent-demo logs deploy/inventory -c agent`). A role name in `auto_auth` that OpenBao does not know makes every login fail, so no template runs. A `destination` that is not the file the application reads makes the agent write a file nobody serves, so `/config` returns `404` even though the log shows a successful render.

You can now read and write a template, make the agent render again within seconds of a new version, and find a broken template from the agent's log. The open question is what to do when a program reads environment variables instead of a file.

## Common pitfalls

> [!WARNING]
> - **Writing a `destination` the application does not read.** The agent renders without an error and the application still has no file. Compare the path with the application's configuration.
> - **Writing `.Data.field` for KV version 2.** Your fields are at `.Data.data.field`; the first `.Data` is the API's, the second the engine's.
> - **Expecting new versions at once.** KV version 2 is read again only every `static_secret_render_interval`, five minutes by default.
> - **Restarting the pod after every secret change.** That hides whether rendering works. The point of the agent is that the file follows the secret on its own.

## Your mission: Render The Inventory Configuration With OpenBao Agent

You can now configure auto-auth and templates and read the agent's log when the file does not appear. The graded lab gives you an `inventory` app whose agent neither logs in nor renders, and asks you to fix the configuration so the app serves the secret and follows a new version, without putting a token into the pod.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-020-01
astrona start ats-116-playground-020-01
```
