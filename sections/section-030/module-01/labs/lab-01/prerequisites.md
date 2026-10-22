# Prerequisites

Before starting this lab you should be able to:

- Edit a Deployment and add a container to its pod template.
- Explain what a Kubernetes service account and an OpenBao policy are.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **OpenBao 2.7.1**, initialized and unsealed, in the namespace `openbao`, and the `bao` command-line tool on your PATH. The lab-only root token is in the Secret `openbao-init`; a real installation never keeps it there.
- A KV version 2 secrets engine at `secret/` with the secret `secret/inventory/config`, and the Kubernetes auth method at `auth/kubernetes`.
- The namespace **`proxy-demo`**, prepared as the task describes, and a `tester` pod in the namespace `clients`.

Nothing the task asks you to create has been created for you.

## Working rules

- Everything is graded on the **final state** of the cluster and of OpenBao, so leave your fix in place.
- Change one thing at a time and check again. A second change made on a guess makes the first one impossible to judge.
- Start the port-forward in a second terminal before you use `bao` on your machine: `kubectl -n openbao port-forward svc/openbao 8200:8200`, then `export BAO_ADDR=http://openbao.localtest.me:8200`.
