# Summary

The agent injector adds OpenBao Agent to pods from annotations, so a team that deploys an application writes a few lines on its pod template instead of a second container, volumes and an agent configuration. The application reads a file and never changes.

## What you learned

The `openbao` Helm chart installs the injector, a Kubernetes mutating admission webhook. The chart's injector is HashiCorp's `vault-k8s`, because OpenBao's own `openbao-k8s` publishes no image yet, and it injects the OpenBao image, whose `vault` link starts OpenBao Agent. That is why the annotations start with `vault.hashicorp.com/`, the files appear in `/vault/secrets/`, and the injected containers are called `vault-agent-init` and `vault-agent`. The webhook's `failurePolicy` is `Ignore`, so a pod created while the injector is down starts without an agent and without an error.

The annotations belong on the pod template, not on the Deployment. `agent-inject: "true"` asks for an agent, `role` names the Kubernetes auth role, `agent-inject-secret-<name>` names the secret and the file, `agent-inject-template-<name>` shapes the file, and `template-static-secret-render-interval` makes KV version 2 changes arrive quickly. The init container writes the file before the application starts, and the sidecar keeps it up to date; `agent-pre-populate-only` drops the sidecar. The role must bind the pod's service account and namespace to a narrow policy. Annotation changes reach only new pods.

Troubleshooting starts with one question: does the pod carry `vault.hashicorp.com/agent-inject-status: injected`? If not, look at where the annotations are, at their keys and values, and at whether the injector was running. If so, read `vault-agent-init`: a refused login points at the role, a refused read at the policy, and `<no value>` in the file at the template. The key facts to remember are these:

- Annotations on `spec.template.metadata.annotations`, prefix `vault.hashicorp.com/`.
- Secrets in `/vault/secrets/<name>`; the init container must finish before the application starts.
- Role bound to the pod's own service account, policy as narrow as the secret paths.
- No status annotation means not injected; `Init:0/1` means the agent cannot log in or read.

<!-- astrona:playground:destroy -->
