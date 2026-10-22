# Deliver Secrets To Pods With The Agent Injector - Playground

- **Slug:** ats-116-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground - clean environment, no task, no grading

OpenBao 2.7.1 on a `kind` cluster, initialized and unsealed, with the module's
workloads in the namespace `inventory`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-116-playground-040-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap only) |
| `bootstrap/prepare.sh` | Installs OpenBao, seeds it and applies `manifests/app.yaml` |
| `manifests/` | Helm values, the tester pod, the module's workloads |
| `docs/overview.md` | What the environment contains and ideas to try |

The scripts were generated; shared pieces are identical in every environment
of this repository. Change them everywhere at once.
