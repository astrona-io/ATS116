# Template Options

The `template` stanza has more settings than `destination` and `contents`. They decide where the template text comes from, who can read the file, what happens when a field is missing, and what the agent does after each render. This part goes through the settings that matter in practice.

## Where the template text comes from

Give the template either `contents`, inline in the agent configuration, or `source`, a path to a template file. Use `source` when the template is long or shared. The file must be present in the agent's container, for example mounted from a ConfigMap. Use `contents` for short templates so that the whole change fits in one ConfigMap.

```hcl
template {
  source      = "/etc/openbao-agent/templates/config.ctmpl"
  destination = "/etc/inventory/config.env"
}
```

## Where and how the file is written

| Setting | What it does |
| --- | --- |
| `destination` | The file to write. Required. |
| `create_dest_dirs` | Creates missing parent directories. The default is `true`. |
| `perms` | The file mode, as a string such as `"0600"`. The default is `"0644"`. |
| `backup` | Keeps a copy of the previous file with the suffix `.bak` when `true`. |
| `sandbox_path` | Allows `file` and the `source` setting to read only below this directory. |

A container that reads the file as a different user needs a mode that user can read. The mode applies to the file only; the user who owns it is the user the agent runs as. Set `perms` to `"0600"` for anything the web server does not need, such as a private key.

## Missing keys and errors

By default a missing field renders as `<no value>` and the agent logs nothing. Set `error_on_missing_key = true` to make a missing field an error, and the file stays as it was. In the agent log the error names the template and the field. Use it on every template that matters, because a file with `<no value>` in it looks valid to the application.

## Delimiters

`left_delimiter` and `right_delimiter` replace `{{` and `}}`. Use them when the file you render contains `{{` and `}}` as text, for example a Helm chart, a Go template or a Prometheus rule:

```hcl
template {
  left_delimiter  = "[["
  right_delimiter = "]]"
  destination     = "/etc/inventory/rules.yaml"
  contents        = <<EOT
[[ with secret "secret/data/inventory/config" ]]user: [[ .Data.data.db_user ]]
text: "{{ keep this as written }}"
[[ end ]]
EOT
}
```

## Running a command after a render

`command` runs a shell command after the template is written, and `command_timeout` stops it after that time; the default is 30 seconds. A reload of the application is the usual use:

```hcl
template {
  destination     = "/etc/inventory/config.env"
  command         = "kill -HUP $(cat /run/app.pid)"
  command_timeout = "10s"
  contents        = "..."
}
```

The command runs in the agent's container, so it can reach only processes and files that container sees. When the application runs in another container of the pod, a shared process namespace or the exec mode from the process supervisor part of the previous module is the way to signal it. The command runs after every render that changed the file, not on every check.

## Waiting before a render

`wait` holds back a render until the dependencies stop changing. `min` is the quiet period and `max` is the longest the agent waits:

```hcl
template {
  wait {
    min = "5s"
    max = "30s"
  }
  ...
}
```

Without `wait`, two quick changes can cause two renders and two commands. With it, the agent waits for five seconds of quiet, or thirty seconds in total, and renders once.

## Try it

1. In the playground, set `error_on_missing_key = true` on your JSON template and change one field to `.Data.data.db_hots`. Restart the pod.
2. Read the agent log with `kubectl -n agent-demo logs deploy/inventory -c agent | tail -n 20`. The error names the missing field.
3. Remove the setting and restart again. `/config.json` now contains a `<no value>` where the field should be.
4. Set `perms = "0600"` and `backup = true`, restart, and run `kubectl -n agent-demo exec deploy/inventory -c agent -- ls -l /etc/inventory`.

## Common pitfalls

> [!WARNING]
> - **Leaving `error_on_missing_key` off.** The file looks valid and holds `<no value>`.
> - **Setting `perms` the application cannot read.** The render succeeds and the application fails to open the file.
> - **Running a long `command`.** A command that does not finish within `command_timeout` is stopped, and the agent logs the timeout.
> - **Using delimiters that appear in the data.** Pick a pair that cannot occur in the rest of the file.
