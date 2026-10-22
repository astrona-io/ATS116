# Section 020: OpenBao Agent

Most applications should not talk to OpenBao at all. They read a configuration file or environment variables, as they always have. OpenBao Agent closes the gap: it runs next to the application, logs in to OpenBao on its own, keeps its token alive, and writes the secrets into the file the application already reads. When a secret changes, the agent writes the file again.

This section runs the agent as a second container in the application's pod, the pattern every later integration builds on. The application, an `nginx` server that serves its configuration file at `/config`, never changes.

## What you will learn

- Auto-auth: how the agent logs in with the pod's Kubernetes service account, and where the `sink` writes the token.
- The agent configuration file: the `vault`, `auto_auth`, `template_config` and `template` stanzas.
- The template language: `with secret`, the `.Data.data` fields of a KV version 2 secret, and what happens when a field is missing.
- When the agent renders again: renewals, the static secret render interval, and how to make a new version show up quickly.
- Process supervisor mode: secrets as environment variables of a child process that the agent restarts.

## The learning path

The module starts at its landing page, which also launches the playground. The playground runs the `inventory` app in the namespace `agent-demo` with a working agent next to it.

### 1. Render Secrets Into Files With OpenBao Agent

1. Auto-Auth And Sinks
2. Rendering Secrets With Templates, followed by the lab **Render The Inventory Configuration With OpenBao Agent**
3. Secrets As Environment Variables With Process Supervisor Mode
4. Summary

## Section capstone: Log The Agent In With AppRole And Keep The File Fresh

The capstone is one graded scenario that combines the whole module. A batch team runs the agent with AppRole credentials from a Kubernetes Secret in the namespace `agentcapstone`, and its configuration file never appears. Find every reason, fix them without giving the agent a static token, and prove that a new secret version reaches the application within a minute. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-116-capstone-020
```
