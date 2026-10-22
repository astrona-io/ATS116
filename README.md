# ATS116 — OpenBao Agent, Proxy & Application Integration

Course material for the **OpenBao Agent, Proxy & Application Integration**
domain of the Astrona OpenBao training path
([ATP022](https://github.com/astrona-io/ATP022)), which is **15% of the path**.
Written for **OpenBao v2.7.1**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the OpenBao 2.7 documentation and source. None has been started on a
> cluster, and no lab has passed `astrona test` yet. See `CLAUDE.md`, which
> also records why the injector's names still say `vault`.

The course opens with an Introduction in `sections/intro/` (welcome, machine
setup, how the course is made). Each section contains a module (landing page,
deep-dive parts, summary, playground, graded lab) and a capstone.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | The OpenBao HTTP API | 1 | 1 + capstone | HTTP API |
| [020](sections/section-020) | OpenBao Agent | 1 | 1 + capstone | Agent |
| [030](sections/section-030) | OpenBao Proxy And Caching | 1 | 1 + capstone | Proxy |
| [040](sections/section-040) | The Kubernetes Agent Injector | 1 | 1 + capstone | Injector |

The order goes from the most direct way to deliver a secret to the most
automatic one: the application calls the API itself, then an agent writes a
file next to it, then a proxy adds the token for it, and finally Kubernetes
adds the agent from annotations.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Talk To OpenBao Over HTTP](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Render Secrets Into Files With OpenBao Agent](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Give Applications A Token-Free Path With OpenBao Proxy](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |
| 040-01 | [Deliver Secrets To Pods With The Agent Injector](sections/section-040/module-01/course.md) | 3 | [lab-01](sections/section-040/module-01/labs/lab-01) |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Script That Calls The OpenBao API | token read from `.data`, a plain `GET` instead of `LIST`, reads without `data/` |
| [020](sections/section-020/capstone/labs/lab-01) | Log The Agent In With AppRole And Keep The File Fresh | wrong role ID file path, a policy path typo, a ten-minute render interval |
| [030](sections/section-030/capstone/labs/lab-01) | Move An App From A Static Token To OpenBao Proxy | a long-lived token in the `nginx` configuration, no service account, no proxy |
| [040](sections/section-040/capstone/labs/lab-01) | Repair Secret Injection For The Inventory App | annotations on the Deployment, a role bound to the wrong service account, `.Data.db_host` |

---

## The lab environment

Every environment is a **kind** cluster with OpenBao 2.7.1 (chart `openbao`
0.30.4) initialized and unsealed, the `bao` CLI and Helm 3.22.1 installed on
the machine, a KV version 2 engine at `secret/` and the Kubernetes auth
method. The lab-only unseal key and root token are in the Secret
`openbao-init`. Section 040 adds the agent injector
(`hashicorp/vault-k8s:1.7.6`, injecting `quay.io/openbao/openbao:2.7.1`).

OpenBao answers at `http://openbao.localtest.me:8200` on the reader's machine
(through `kubectl -n openbao port-forward svc/openbao 8200:8200`) and inside
the cluster (through a CoreDNS rewrite). Pods use
`http://openbao.openbao.svc:8200`.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Graders need `kubectl` and `jq` on the machine. Each lab grades the final
state with independent checks, and several reject the plausible-but-wrong fix
(a token in the pod, a role bound to `*`, a widened policy, a changed
application, a restart instead of a re-render).
