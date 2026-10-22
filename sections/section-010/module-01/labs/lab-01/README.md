---
estimated_duration: 20m
---

# Hand Over A Secret With A Wrapped Response

- **Slug:** ats-116-lab-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `api-demo`. Read `question.md` for the task;
`solution.md` is the walkthrough.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-116-lab-010-01
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | Installs OpenBao and creates the starting state |
| `manifests/` | Helm values, the tester pod, the starting workloads |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for OpenBao before the reference solution runs |
| `validation/` | Grading scripts, one per check |

Graders need `kubectl` and `jq` on the machine. The scripts were generated;
shared pieces are identical in every environment of this repository.
