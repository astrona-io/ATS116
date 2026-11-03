# Operating The Injector

The first three parts were about one application. Someone also has to run the injector for every application in the cluster. When the injector is down, slow or too eager, the effects are felt by every team that uses it. This part covers what to check and which settings decide how the injector behaves for the whole cluster.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## What is running

The chart installs the injector as a Deployment in the `openbao` namespace and registers a mutating webhook configuration. List both:

```sh
kubectl -n openbao get deployment,pods -l app.kubernetes.io/name=openbao-agent-injector
kubectl get mutatingwebhookconfiguration
```

The webhook configuration names the service the Kubernetes API server calls, the operations it applies to (pod creation) and the `failurePolicy`. The injector serves HTTPS on the webhook port and keeps its own certificate; the chart patches the CA into the webhook configuration.

## failurePolicy decides what a down injector means

The chart sets `failurePolicy: Ignore`. When the injector cannot be reached, the API server accepts the pod as it is. The pod starts without an agent and without an error. The application then fails on its own, because the file it reads does not exist.

The other value, `Fail`, makes the API server refuse the pod, so no pod without an agent can start. That is safer for secrets and riskier for the cluster: with `Fail`, a down injector blocks every pod that the webhook matches, which can include pods the injector needs to come back. Use `Fail` only with a selector that keeps the injector's own namespace and system namespaces out of the webhook, and with more than one injector replica.

## Chart settings that matter

These are values of the `openbao` Helm chart under `injector`:

| Value | What it controls |
| --- | --- |
| `injector.enabled` | Installs the injector |
| `injector.replicas` | The number of injector pods. Use more than one in production. |
| `injector.failurePolicy` | `Ignore` or `Fail` for the webhook |
| `injector.namespaceSelector`, `injector.objectSelector` | Which namespaces and objects the webhook is called for |
| `injector.logLevel` | The injector's log level |
| `injector.externalVaultAddr` | The OpenBao address for pods, when OpenBao runs outside this cluster |
| `injector.agentDefaults` | Default CPU and memory for the injected containers |

Change a value with `helm upgrade` and the new settings apply to pods created after the upgrade. Pods that were already injected keep the containers they were given.

## Checking the injector's health

Read the injector's log when pods are not being injected. A line per admitted pod shows that the webhook was called:

```sh
kubectl -n openbao logs deploy/openbao-agent-injector --tail=30
```

If the log shows nothing when a pod is created, the API server never called the injector. Look at the webhook configuration's selectors, then at network policies between the API server and the injector's port, then at the injector's pods.

## Changing the agent image and defaults

The injector uses a default agent image from its own configuration. A pod can override it with the annotation `vault.hashicorp.com/agent-image`. Keep one agent version across the cluster; a pod-level override makes the next upgrade harder to reason about. Upgrade the agent image first in one namespace, then in the rest.

## Try it

1. In the playground, list the mutating webhook configuration with `kubectl get mutatingwebhookconfiguration -o yaml` and find `failurePolicy`.
2. Scale the injector to zero with `kubectl -n openbao scale deployment/openbao-agent-injector --replicas=0`. Delete the application pod and run `pod_status`. The new pod has no injected containers and no error.
3. Scale the injector back to one replica. Delete the pod again and check the status.
4. Read the injector's log with the command above and find the lines for the pod you created.

## Common pitfalls

> [!WARNING]
> - **Setting `failurePolicy: Fail` with one replica.** A restart of the injector blocks pod creation.
> - **Believing a running application is injected.** Check the status annotation of each pod, not the Deployment.
> - **Upgrading the chart and expecting running pods to change.** Only new pods get the new settings.
> - **Overriding the agent image on single applications.** Version drift makes upgrades harder.
