# Agent Configuration And Troubleshooting

An agent that runs for months needs more than a login and a template. It must survive a restart of OpenBao, log what it does, and tell you why it fails. This part reads the settings around the stanzas you already know, runs the agent with more logging, and ties each common failure to the log line and the setting behind it.

The commands below need the playground's `inventory` pod in `agent-demo`.

## Settings around the stanzas

Besides `vault`, `auto_auth`, `template_config` and `template`, the agent file accepts a few top-level settings and more options inside `vault`:

| Setting | What it does |
| --- | --- |
| `pid_file` | Writes the agent's process ID to a file |
| `log_level` | One of `trace`, `debug`, `info`, `warn` and `error`; the command-line flag `-log-level` overrides it |
| `exit_after_auth` | Logs in once, writes the sinks, then stops. Useful for init containers |
| `vault { retry { num_retries } }` | How many times the agent retries a failed request to OpenBao before it gives up on that request |
| `vault { ca_cert, client_cert, client_key }` | The certificate authority and the client certificate for a server that uses TLS |
| `vault { tls_skip_verify }` | Turns off certificate checks. Never use it outside a lab |

The `vault` stanza is the only place where the agent learns the server address. Without it, the agent uses the environment variable `BAO_ADDR`. The command line can also take more than one `-config` flag, either files or directories, and the agent merges them. Look at how the playground starts the agent and read its first log lines:

<!-- astrona:playground:renew -->

```sh
kubectl -n agent-demo get deployment inventory -o jsonpath='{.spec.template.spec.containers[?(@.name=="agent")].command}{"\n"}'
kubectl -n agent-demo logs deploy/inventory -c agent | head -n 20
```

The command is `bao agent -config=/etc/openbao-agent/agent.hcl`. The log shows the version, the configuration the agent loaded with secrets removed, and the start of the auth handler and the template server. The first lines are the place to check that the agent read the file you think it read.

## More logging

The default level is `info`, which shows logins, renewals and renders. When that is not enough, set `log_level = "debug"` in the agent file and restart the pod. At `debug` the agent also logs each request to OpenBao and each template it decides to render again. Add the line, restart and read:

```sh
kubectl -n agent-demo edit configmap agent-config
kubectl -n agent-demo rollout restart deployment/inventory
kubectl -n agent-demo rollout status deployment/inventory
kubectl -n agent-demo logs deploy/inventory -c agent | tail -n 30
```

In the editor, add `log_level = "debug"` as the first line of `agent.hcl`, above the `vault` stanza, and save. Debug output holds paths and lease information, so turn it off again when you are done.

## From a symptom to a setting

Most failures fall into a few groups. Match the symptom first, then read the log line the agent writes for it:

| Symptom | Where to look | Usual cause |
| --- | --- | --- |
| No file, the log repeats an authentication error | `auto_auth` and the Kubernetes auth role | The role name is wrong, or the role does not bind this service account and namespace |
| No file, the log shows `permission denied` on a read | The role's policy | The policy lacks `read` on `secret/data/...` |
| File exists, fields are `<no value>` | The template | A field read at `.Data.x` instead of `.Data.data.x` |
| File exists, but the application serves `404` | `destination` | The agent writes a path the application does not read |
| File never changes | `static_secret_render_interval` | The default is five minutes |
| Agent cannot reach OpenBao at all | `vault.address` | A wrong host name or port, or OpenBao is sealed |

Tell the last case from the first by the error. A connection error means the agent never reached the server; an authentication error means it reached the server and the server refused the login. Check the server side with `sys/health`; a sealed server answers `503` to everything.

Remove the debug line again, so the agent returns to its normal level:

```sh
kubectl -n agent-demo edit configmap agent-config
kubectl -n agent-demo rollout restart deployment/inventory
```

You can now read the agent's settings, raise its log level and match a symptom to a stanza. The next step is to look at the other ways an agent can log in, because Kubernetes is only one of them.

## Common pitfalls

> [!WARNING]
> - **Editing the ConfigMap and expecting the agent to notice.** The agent reads its file at start. Restart the pod.
> - **Leaving `log_level = "debug"` on.** It floods the log and shows paths.
> - **Using `tls_skip_verify` to "fix" a certificate error.** Fix the `ca_cert` instead.
> - **Reading only the application's log.** The application does not know why its file is missing. The agent's log does.
