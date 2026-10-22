---
estimated_duration: 35m
---

# Log The Agent In With AppRole And Keep The File Fresh

- **Slug:** ats-116-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `agentcapstone`. Read `question.md` for the task;
`solution.md` is the walkthrough.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-116-capstone-020
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
