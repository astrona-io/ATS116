# Shaping The Files

A file written without a template is not usable by most programs. This part shows the default output, writes templates for the formats applications read, and sets the permissions and the command that runs after each render. A graded lab follows.

## The default output

Without a template annotation, the injector writes every field of the response in Go's map notation. For a KV version 2 secret, this prints the keys `data` and `metadata` as nested maps, not as lines a program can read. Always write a template for a KV version 2 secret.

## The template annotation

`agent-inject-template-<name>` holds the template, using the same language as the agent's own templates: `with`, `range`, variables and functions such as `toJSON`. In a Deployment, the annotation value is a YAML block scalar:

```yaml
vault.hashicorp.com/agent-inject-template-config.env: |
  {{- with secret "secret/data/inventory/config" -}}
  DB_HOST={{ .Data.data.db_host }}
  DB_USER={{ .Data.data.db_user }}
  API_KEY={{ .Data.data.api_key }}
  {{- end }}
```

The `{{-` and `-}}` remove the whitespace around the action. Without them, the file starts and ends with a line break, which most programs ignore and some do not.

For JSON, use `toJSON` for every string and write numbers without quotes:

```yaml
vault.hashicorp.com/agent-inject-template-api: |
  {{- with secret "secret/data/inventory/api" -}}
  {
    "api_url": {{ .Data.data.api_url | toJSON }},
    "api_token": {{ .Data.data.api_token | toJSON }},
    "version": {{ .Data.metadata.version }}
  }
  {{- end }}
```

A template can read more than one secret; each `with` block reads one:

```yaml
{{- with secret "secret/data/inventory/config" -}}DB_HOST={{ .Data.data.db_host }}{{ end }}
{{ with secret "secret/data/inventory/api" -}}API_URL={{ .Data.data.api_url }}{{- end }}
```

Only the secrets named by an `agent-inject-secret-` annotation are read ahead of time; a template that reads a path without an annotation still works, but then the injector has no record of the path.

## File permissions

`agent-inject-perms-<name>` sets the mode of the file, as a string such as `"0400"`. The default is `0644`. The user that owns the file is the user the agent runs as, and the application's container may run as another user. A mode that the application's user cannot read leaves the application with a permission error. Use `agent-run-as-user` in the next part when the application runs as a specific user and you need the file to be owned by it.

## Running a command after a render

`agent-inject-command-<name>` runs a command in the agent sidecar after the file is rendered:

```yaml
vault.hashicorp.com/agent-inject-command-config.env: "touch /vault/secrets/reloaded"
```

The command runs in the sidecar container, not in the application. It cannot send a signal to a process in another container unless the pod shares its process namespace. For an application that reads files on demand, no command is needed. For one that reads the file once at start, the command has to cause a reload, or you restart the pod.

## When the schedule applies

`vault.hashicorp.com/template-static-secret-render-interval` sets how often KV version 2 secrets are read again, for every secret of the pod. The default is five minutes. The playground sets 15 seconds.

## Your mission: Inject A Second Secret As A JSON File

You can now write the annotations for a second secret, name its file and shape it as JSON. The graded lab gives you an `inventory` app that already gets one secret from the injector and serves another file that does not exist yet. You add the second secret without breaking the first.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-040-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-040/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-040-02
astrona start ats-116-playground-040-02
```
