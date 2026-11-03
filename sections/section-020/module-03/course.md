# Templates In Depth: Language, Options And Schedule

A template is the part of OpenBao Agent that applications see. The agent logs in, reads secrets and writes files, and every one of those files comes from a template. A small template is easy. A template that writes JSON, shows the version of the secret, loops over every field, fails when a field is missing and renews a certificate before it expires needs more of the language and more of the options.

This module is about those details. Keep one sentence in mind: **a template is a function from secrets to a file, and the agent decides when to run it again, so you control both what the file says and how fresh it is.**

The module has four parts. **The Template Language** covers the functions, the control blocks and the whitespace rules. **Template Options** covers every setting of the `template` stanza: source, permissions, backups, delimiters, `command` and `error_on_missing_key`. **When The Agent Renders Again** covers `static_secret_render_interval`, `wait`, leases and the `template_config` stanza; a graded lab follows it. **Certificates And Dynamic Secrets** renders a certificate from the PKI engine with `pkiCert` and shows how dynamic secrets set their own render time.

## Learning objectives

After this module you can:

- Read a KV version 2 secret, list a path and loop over fields in a template.
- Use `if`, `range`, variables, `scratch`, `env`, `file`, `toJSON` and `printf`, and trim whitespace.
- Set `source`, `contents`, `destination`, `perms`, `backup`, `create_dest_dirs`, `error_on_missing_key`, `command`, `command_timeout`, `left_delimiter` and `right_delimiter`.
- Explain when the agent renders again for static secrets, for dynamic secrets and for the `wait` option.
- Set `static_secret_render_interval`, `exit_on_retry_failure` and `max_connections_per_host` in `template_config`.
- Render a certificate and key with `pkiCert` and explain when it is issued again.

## Before you start

You need to know what a KV version 2 secret is, what a token and a policy are, and that the agent reads one HCL file with `vault`, `auto_auth` and `template` stanzas. The previous module shows how the agent logs in and why the first template works.

Your playground is a single-node `kind` cluster with **OpenBao 2.7.1** in the namespace `openbao`, initialized and unsealed. The namespace **`agent-demo`** runs the `inventory` pod: an `agent` container and an `nginx` container sharing an in-memory volume. The web server serves three files from that volume, if they exist: `/config`, `/config.json` and `/tls.crt`. In OpenBao:

| Object | What it is |
| --- | --- |
| KV version 2 at `secret/` | The secret `secret/inventory/config` |
| PKI at `pki/` | A root certificate and the role `web` for `inventory.example.com`, up to one hour |
| Policies `inventory-reader`, `pki-issuer` | Read the inventory secrets; issue from `pki/issue/web` |
| Kubernetes auth role `inventory-agent` | The login the agent uses, with both policies |
| `tester` (namespace `clients`) | A pod with `curl` and `jq` |

The lab-only root token is in the Kubernetes Secret `openbao-init`; a real installation never keeps it there.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
