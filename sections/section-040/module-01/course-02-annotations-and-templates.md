# Annotations And Templates

The injector writes the agent's configuration for you, but it needs to know four things: that the pod wants an agent, which role the agent logs in with, which secrets to read, and how to write them into files. All four are annotations on the pod. This part reads the annotations of the playground's app, explains each one, and shows the change a new secret version makes.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## Where the annotations go

The injector looks at pods, so the annotations must be on the pod, which for a Deployment means on its pod template: `spec.template.metadata.annotations`. Annotations under the Deployment's own `metadata` are never copied to its pods, and the injector never sees them. Print the pod template's annotations:

<!-- astrona:playground:renew -->

```sh
kubectl -n inventory get deployment inventory -o jsonpath='{.spec.template.metadata.annotations}' | jq
```

These are the annotations, as they appear in the Deployment's YAML:

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "inventory"
vault.hashicorp.com/agent-inject-secret-config.env: "secret/data/inventory/config"
vault.hashicorp.com/agent-inject-template-config.env: |
  {{- with secret "secret/data/inventory/config" -}}
  DB_HOST={{ .Data.data.db_host }}
  DB_USER={{ .Data.data.db_user }}
  API_KEY={{ .Data.data.api_key }}
  {{- end }}
vault.hashicorp.com/template-static-secret-render-interval: "15s"
```

## What each annotation does

Each annotation sets one part of the agent configuration the injector generates. The secret annotations share a name, here `config.env`, and that name becomes the file name in `/vault/secrets/`:

| Annotation | What it sets |
| --- | --- |
| `agent-inject: "true"` | Inject the agent into this pod at all |
| `role` | The Kubernetes auth role the agent logs in with |
| `agent-inject-secret-<name>` | Read this secret path and write it to `/vault/secrets/<name>` |
| `agent-inject-template-<name>` | The template for that file, in the same language as agent templates |
| `template-static-secret-render-interval` | How often to read KV version 2 secrets again; the agent's default is five minutes |
| `agent-pre-populate-only: "true"` | Inject only the init container: the file is written once at start, with no sidecar to update it |
| `agent-inject-perms-<name>` | The file mode of `/vault/secrets/<name>`, for example `"0440"` |

Without a template annotation, the injector writes the whole secret in a default form, which is rarely what an application reads. With one, the file holds exactly what the template renders. The template language is the agent's: `{{ with secret "..." }}` reads the secret, and the fields of a KV version 2 secret are at `.Data.data.<field>`. The `{{-` and `-}}` trim the line breaks around the tags, so the file starts with `DB_HOST=` and has no empty lines.

## The role behind the annotations

The `role` annotation only names a role; OpenBao decides whether the pod may use it. The injected agent sends the pod's service account token, so the role must bind the pod's service account and namespace. Compare the two:

```sh
kubectl -n inventory get deployment inventory -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
bao read auth/kubernetes/role/inventory
```

The pod runs as `inventory`, and the role binds `inventory` in the namespace `inventory` to `inventory-reader`. If the names differ, the init container never finishes, because it keeps trying to log in, and the application container never starts.

## A new version reaches the pod

With the sidecar running and a 15 second render interval, a new secret version reaches the file without a restart:

```sh
bao kv patch secret/inventory/config api_key=injected-update
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/config
```

`API_KEY` shows the new value, and `kubectl -n inventory get pods` shows the same pod. With `agent-pre-populate-only: "true"` there would be no sidecar, and the file would keep the value from the pod's start until the pod is replaced.

Changing an annotation is different from changing a secret. Annotations are part of the pod template, so editing them makes the Deployment roll out new pods, and the injector reads the new annotations when it changes each new pod. Existing pods never pick up new annotations.

You can now write the annotations that inject the agent, name the file, shape it with a template and set the render interval, and you know which role and service account they depend on. The graded lab asks you to add all of this to an app that has none of it.

## Common pitfalls

> [!WARNING]
> - **Annotating the Deployment instead of the pod template.** Kubernetes does not copy Deployment annotations to pods; the injector never sees them.
> - **Giving the secret and template annotations different names.** The template applies to the secret with the same `<name>`; a mismatch renders the default format.
> - **Writing `.Data.field` in the template.** KV version 2 fields are at `.Data.data.field`; the wrong depth renders `<no value>`.
> - **Changing the template and waiting for the old pod.** Annotation changes reach only new pods. Let the rollout finish.

## Your mission: Deliver Secrets To The Inventory Pods Without Code Changes

You can now inject OpenBao Agent with annotations and bind it to a narrow role. The graded lab gives you the `inventory` app with no annotations and no role, and asks you to make it serve the rendered secret and follow new versions without changing its image or command.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-040-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-040/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-040-01
astrona start ats-116-playground-040-01
```
