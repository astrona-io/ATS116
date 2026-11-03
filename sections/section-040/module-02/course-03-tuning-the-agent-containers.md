# Tuning The Agent Containers

The injected containers are real containers with real resource use, an order and a lifetime. A pod that is rescheduled, scaled or run with strict limits needs those set on purpose. This part covers the annotations that change the injected containers.

## Resources

The injected containers get defaults from the injector. Set your own on the pod template:

| Annotation | What it sets |
| --- | --- |
| `vault.hashicorp.com/agent-requests-cpu`, `agent-requests-mem` | The requests of the injected containers |
| `vault.hashicorp.com/agent-limits-cpu`, `agent-limits-mem` | The limits of the sidecar |

A namespace with a quota counts the injected containers too. A pod that fits the quota without the agent can fail to be created with it. Set the values low enough for the quota and high enough that the sidecar is not stopped for using memory when a template reads many secrets.

## Order of the init containers

The injected init container, `vault-agent-init`, is added after any init containers you already have, so it runs after them. If your own init container needs a secret, it has to run after the agent. `vault.hashicorp.com/agent-init-first: "true"` puts the agent init container first.

## Pre-populate and the sidecar

`agent-pre-populate` (default `"true"`) adds the init container, so the files exist before the application starts. `agent-pre-populate-only: "true"` leaves out the sidecar, so the files are written once and never updated. This suits a short job. Do not use it for a service that needs a new secret version without a restart.

If you set `agent-pre-populate: "false"` the init container is left out. The application then starts before the files exist, and the sidecar creates them when it can.

## The token file

By default only the secret files are written. `vault.hashicorp.com/agent-inject-token: "true"` also writes the agent's token to a file named `.vault-token` in the agent's home directory in the pod. This gives the application a token to call the API itself. Do this only when the application needs it, because the token is then readable by every container that mounts the volume. For an application that only reads files, leave it off.

## Revoking the token when the pod stops

`vault.hashicorp.com/agent-revoke-on-shutdown: "true"` makes the sidecar revoke its token when the pod shuts down. With `agent-revoke-grace` you set how long to wait for the final renders. This keeps the number of live tokens low in a cluster that starts and stops many pods.

## Users and security context

`agent-run-as-user` and `agent-run-as-group` set the user and group of the injected containers. Set them when the application runs as a specific user and must read files the agent wrote with a restrictive mode. `agent-set-security-context` controls whether the injector sets a security context at all.

## Logging

`vault.hashicorp.com/log-level` sets the sidecar's level (`trace`, `debug`, `info`, `warn`, `error`) and `vault.hashicorp.com/log-format` the format. Raise the level while you investigate and lower it afterwards.

## Try it

1. Add resource annotations to the pod template and read the result with `kubectl -n inventory get pod -l app=inventory -o jsonpath='{.items[0].spec.containers[?(@.name=="vault-agent")].resources}'`.
2. Add `agent-init-first: "true"` and list the init containers with `kubectl -n inventory get pod -l app=inventory -o jsonpath='{.items[0].spec.initContainers[*].name}'`.
3. Add `agent-pre-populate-only: "true"`, patch the secret and check that the file does not change. Then remove it.
4. Add `agent-inject-token: "true"` and find the token file in the pod. Remove the annotation again after you look.

## Common pitfalls

> [!WARNING]
> - **Leaving the default resources in a namespace with a quota.** The pod may not be admitted.
> - **Using `agent-pre-populate-only` for a service.** The file never changes again until the pod restarts.
> - **Injecting the token for convenience.** Every container that mounts the volume can use it.
> - **Raising the log level and forgetting it.** Debug logs fill the log storage.
