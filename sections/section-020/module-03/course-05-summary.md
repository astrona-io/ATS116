# Summary

A template is a function from secrets to a file, and the agent decides when to run it again. You control what the file says with the template language and how it is written with the stanza's options. You control how fresh the file is with the schedule.

## What you learned

The template language reads secrets with `secret` and lists paths with `secrets`. `with` reads and skips the block when the read is empty, `if` and `range` choose and repeat, and variables hold values. Helpers such as `toJSON`, `base64Encode`, `env`, `file` and `scratch` shape the output. `{{-` and `-}}` remove whitespace. KV version 2 fields are at `.Data.data`, and the version is at `.Data.metadata.version`.

The `template` stanza has `source` or `contents`, `destination`, `perms`, `backup`, `create_dest_dirs`, delimiters, `command`, `command_timeout`, `wait` and `error_on_missing_key`. A file with `<no value>` is the usual result of a misspelled field when `error_on_missing_key` is off.

Static secrets render again every `static_secret_render_interval`, five minutes by default. Leased secrets render again before the lease runs out. `pkiCert` renders again before the certificate expires. `template_config` also sets `exit_on_retry_failure` and `max_connections_per_host`. The key facts to remember are these:

- Use `toJSON` for JSON and `error_on_missing_key = true` for every template that matters.
- Set `static_secret_render_interval` to the delay you can accept, not to the smallest value.
- The file changes without a pod restart; the application must notice, or the template `command` must tell it.
- Never serve a private key; give it its own file and mode `0600`.

<!-- astrona:playground:destroy -->
