# When The Agent Renders Again

A rendered file is a snapshot. The agent decides when to take the next one, and the rule differs by the kind of secret. This part explains the three triggers, the settings that control them and how to read the agent's log to see which one fired.

## Static secrets: a timer

A KV version 2 secret has no lease, so the agent has nothing to track. It reads the secret again every `static_secret_render_interval`, five minutes by default, and renders again if the data changed. Set the interval in the `template_config` stanza, which applies to every template of the agent:

```hcl
template_config {
  static_secret_render_interval = "30s"
}
```

A short interval makes changes visible sooner and sends more requests to OpenBao. With many pods each rendering a handful of secrets, the product of the number of pods and the number of secrets divided by the interval is the request rate on the server.

## Dynamic secrets: the lease

A secret with a lease, such as a database credential, is renewed by the agent. When the lease can no longer be renewed because it has reached its maximum TTL, the agent reads the secret again before the lease runs out. This renders the new credential at the right time without any setting of yours. The lease TTL and maximum TTL come from the secrets engine's role, not from the agent.

## What `template_config` also sets

| Setting | What it does |
| --- | --- |
| `static_secret_render_interval` | How often static secrets are read again |
| `exit_on_retry_failure` | When `true`, the agent exits if a template cannot be rendered after the retries. A pod restart then makes the problem visible. |
| `max_connections_per_host` | The most connections to OpenBao for template rendering. The default is 10. |

Without `exit_on_retry_failure`, an agent that cannot read a secret keeps retrying and keeps running, and the application keeps the file from before. This is useful when OpenBao can be unreachable for a short time, and dangerous when the secret has been removed and the file keeps serving old data.

## Rendering is not signalling

When the file changes, the application has to notice. A web server that reads the file at each request, as the playground's does, follows at once. A program that reads the file only at start needs the template's `command` to reload it, or a restart. A restart of the pod also repeats the login and all reads, so prefer a reload where the application supports it.

## Reading the log

The agent logs its template work at `info` level. Start the agent with the flag `-log-level=debug` to see each check and each render, and remove the flag afterwards because debug output is large. To follow a render in real time:

```sh
kubectl -n agent-demo logs deploy/inventory -c agent -f
```

## Try it

1. Set `static_secret_render_interval = "5s"` in the playground and restart the pod.
2. Patch the secret with `bao kv patch secret/inventory/config api_key=a1` and run `curl -s http://inventory.agent-demo/config` from the `tester` pod every second until the value changes. Count the seconds.
3. Set the interval to `1m` and repeat the test.
4. Add `wait { min = "10s" max = "20s" }` to the template and patch the secret three times in five seconds. Check how often the file changed.

## Common pitfalls

> [!WARNING]
> - **Expecting changes to arrive at once.** The default interval is five minutes.
> - **Setting a very short interval on many pods.** The request rate on OpenBao grows with the number of pods.
> - **Setting `exit_on_retry_failure` without a restart policy that makes sense.** The pod restarts again and again while OpenBao is down.
> - **Leaving the agent at debug level.** Debug logs grow quickly and are noisy to read.

## Your mission: Render A JSON File With An Agent Template

You can now write a template, choose its options and set the schedule. The graded lab gives you an `inventory` app whose agent renders only one file. You add a second template that writes valid JSON with the current secret version, shorten the schedule, and make a misspelled field fail instead of rendering `<no value>`.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-020-03
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-020/module-03/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-020-03
astrona start ats-116-playground-020-03
```
