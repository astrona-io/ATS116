# Summary

OpenBao Agent lets an application use secrets without knowing that OpenBao exists. It runs next to the application, logs in on its own, and delivers the secrets in the form the application already reads: a file or environment variables.

## What you learned

The agent reads one HCL configuration file. Its `vault` stanza says where OpenBao is, its `auto_auth` stanza says how to log in and where to write the token, `template_config` holds settings for all templates, and each `template` stanza renders one file. With the `kubernetes` method the agent sends the pod's service account token to OpenBao, OpenBao checks it with the Kubernetes API, and a Kubernetes auth role turns the service account into a token with the role's policies. The role must name the exact service account and namespace. A `file` sink writes the token for other processes; the agent's own templates do not need it. The agent renews the token and logs in again when it must, so the application never holds an expired token.

A template reads a secret with `{{ with secret "secret/data/..." }}` and writes fields into a file. For KV version 2 the fields are at `.Data.data.<field>`. The template engine adds `data/` to a KV version 2 path by itself, but writing it out keeps the template, the policy and a `curl` request identical. A field at the wrong depth renders as `<no value>` unless `error_on_missing_key` turns it into an error. The agent reads KV version 2 secrets again every `static_secret_render_interval`, five minutes by default, and rewrites the file, so the application sees a new version without a restart.

Process supervisor mode serves programs that read environment variables. The agent renders `env_template` stanzas, starts the program from its `exec` stanza with those variables, and restarts it when a secret changes. It cannot be combined with file templates in the same agent. The key facts to remember are these:

- Auto-auth gets the token; templates use it; the application reads a file or its environment.
- The Kubernetes auth role must match the pod's service account and namespace exactly.
- KV version 2 fields are at `.Data.data`; new versions arrive every `static_secret_render_interval`.
- When the file does not appear, read the agent's log: login, render, destination.

<!-- astrona:playground:destroy -->
