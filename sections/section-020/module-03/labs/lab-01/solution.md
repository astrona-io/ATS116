# Solution: Render A JSON File With An Agent Template

Work the task yourself first. Running `astrona submit -c sections/section-020/module-03/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: `/config.json` is valid JSON with the three fields and the current numeric version, `/config` still works, a new secret version reaches `/config.json` within 90 seconds without a pod restart, and no token is stored in the pod or its ConfigMaps.

## Step 1: Look at what is served now

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config.json
kubectl -n agent-demo get configmap agent-config -o jsonpath='{.data.agent\.hcl}'
```

`/config` works. `/config.json` returns nothing useful because no template writes that file. The agent configuration has one `template` stanza and no `template_config` stanza, so a new secret version would take the default of five minutes to arrive.

## Step 2: Add the JSON template

Edit the ConfigMap with `kubectl -n agent-demo edit configmap agent-config` and add this after the existing `template` stanza:

```hcl
template {
  destination          = "/etc/inventory/config.json"
  error_on_missing_key = true
  contents             = <<EOT
{{ with secret "secret/data/inventory/config" }}{
  "db_host": {{ .Data.data.db_host | toJSON }},
  "db_user": {{ .Data.data.db_user | toJSON }},
  "api_key": {{ .Data.data.api_key | toJSON }},
  "version": {{ .Data.metadata.version }}
}{{ end }}
EOT
}
```

`toJSON` writes a string with its quotes and escapes, so a value with a quote or a backslash cannot break the file. `.Data.metadata.version` is a number and is written without quotes. `error_on_missing_key = true` makes a misspelled field an error in the log instead of an empty value.

## Step 3: Shorten the render interval

Add this stanza at the top level of the same file, next to the `auto_auth` stanza:

```hcl
template_config {
  static_secret_render_interval = "15s"
}
```

## Step 4: Restart the pod once and check

The agent reads its configuration only at start, so restart it once. This is the only restart in the task:

```sh
kubectl -n agent-demo rollout restart deployment/inventory
kubectl -n agent-demo rollout status deployment/inventory
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config.json | jq .
```

## Step 5: Prove a new version arrives

```sh
bao kv patch secret/inventory/config api_key=changed-by-me
sleep 30
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config.json | jq .
```

`api_key` has the new value and `version` has gone up by one. If it has not, read `kubectl -n agent-demo logs deploy/inventory -c agent | tail -n 30`.

## Common mistakes

- Writing `"version": "{{ .Data.metadata.version }}"` with quotes. The grader needs a number.
- Using `.Data.db_host` instead of `.Data.data.db_host`. For a KV version 2 secret the fields are one level deeper.
- Leaving out `template_config`, so a new version takes five minutes.
- Replacing the first template instead of adding a second one.
