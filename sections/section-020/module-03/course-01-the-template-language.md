# The Template Language

The agent's templates use Go's `text/template` language with extra functions from OpenBao's fork of consul-template. Everything outside `{{ }}` is copied to the file unchanged. Everything inside `{{ }}` is an action: print a value, read a secret, test a condition or loop. This part lists the actions you will use in almost every template and explains the whitespace rules that decide how the file looks.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## Reading secrets

Two functions talk to OpenBao. `secret` reads one path. `secrets` lists the names under a path, like `bao kv list`.

| Function | What it does |
| --- | --- |
| `secret "secret/data/inventory/config"` | Reads one secret. The result has `.Data`, and for KV version 2 your fields are in `.Data.data` and the version in `.Data.metadata.version`. |
| `secrets "secret/metadata/inventory"` | Lists the keys under a path. Use the `metadata/` path for a KV version 2 list. |
| `secret "path" "key=value"` | Sends data with the request, used for paths that need a write, such as PKI issue. |

`with` reads and then makes the result the current value (`.`) until `end`. If the read returns nothing, the whole block is skipped and nothing is written. Use `with` when an empty result should produce an empty file. To keep a copy of the result, assign it to a variable:

```
{{ with $s := secret "secret/data/inventory/config" }}{{ $s.Data.data.db_host }}{{ end }}
```

## Control blocks

`if` tests a value. Empty strings, zero, `false`, and missing values count as false. `range` repeats a block for each item of a list or each key of a map.

```
{{ with secret "secret/data/inventory/config" }}
{{ range $name, $value := .Data.data }}{{ $name | toUpper }}={{ $value }}
{{ end }}
{{ end }}
```

This renders every field of the secret as `NAME=value` without naming them. A field added later appears in the file after the next render. `if` and `else` choose between two outputs:

```
{{ if eq .Data.data.db_user "inventory" }}standard{{ else }}custom{{ end }}
```

The comparison functions are `eq`, `ne`, `lt`, `le`, `gt` and `ge`; combine tests with `and`, `or` and `not`.

## Helper functions

| Function | Use |
| --- | --- |
| `toJSON`, `toJSONPretty`, `toYAML` | Write a value as JSON or YAML with correct quoting |
| `parseJSON` | Read a string that contains JSON into a value you can index |
| `base64Encode`, `base64Decode` | Convert a value to and from base64 |
| `toUpper`, `toLower`, `trimSpace`, `replaceAll` | Change text |
| `join`, `split` | Join a list into text, or split text into a list |
| `printf` | Format a value with a Go format string |
| `env "NAME"` | Read an environment variable of the agent process |
| `file "/path"` | Read a file on disk |
| `timestamp` | The time of the render |
| `scratch` | A place to keep values between blocks of one template |

`toJSON` is the right tool for JSON output. Writing `"{{ .Data.data.api_key }}"` by hand breaks the file when the value contains a quote or a backslash. `{{ .Data.data.api_key | toJSON }}` writes the quotes itself and escapes what needs it. Use `env` for settings that do not come from OpenBao, such as the pod's name if you pass it in as a variable. Use `file` to place a value that was written by another process into the output.

## Whitespace

By default every line break and space around an action stays in the file. A `{{ range }}` on its own line adds an empty line for the action. Write `{{-` to remove the whitespace before an action and `-}}` to remove the whitespace after it:

```
{{- with secret "secret/data/inventory/config" -}}
DB_HOST={{ .Data.data.db_host }}
{{- end }}
```

The first `-` joins the action to the end of the previous text, the last `-` joins the next text to it. The output above is one line without a trailing newline. A space is required between the dash and the action name: `{{- with`, not `{{-with`.

## Try it

In the playground, run these steps:

1. Open the agent configuration with `kubectl -n agent-demo edit configmap agent-config`.
2. Add a second `template` stanza that writes `/etc/inventory/config.json` and renders the secret with `{{ .Data.data | toJSON }}` inside a `with` block.
3. Restart the pod with `kubectl -n agent-demo rollout restart deployment/inventory`.
4. Read the file from the `tester` pod with `curl -s http://inventory.agent-demo/config.json | jq .`.
5. Change the template to loop with `range` and print `NAME=value` lines to `/etc/inventory/config.env`, then restart again.

`jq` fails on a file that is not valid JSON, so it is a quick test of the template.

## Common pitfalls

> [!WARNING]
> - **Writing `.Data.field` for KV version 2.** The fields are at `.Data.data.field`.
> - **Building JSON by hand.** A value with a quote breaks the file. Use `toJSON`.
> - **Using `with` and expecting an error.** A failed read skips the block silently. The file is empty and the log may show nothing about it.
> - **Forgetting that `range` over a map is sorted by key.** The order of lines in the file is alphabetical, not the order you wrote the fields.
