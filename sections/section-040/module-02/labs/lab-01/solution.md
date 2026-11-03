# Solution: Inject A Second Secret As A JSON File

Work the task yourself first. Running `astrona submit -c sections/section-040/module-02/labs/lab-01` after a step tells you which checks pass.

The grader checks that both files exist in the pod, that `/api` is valid JSON with the current fields and numeric version, that `/config` still works, that a new version of the second secret arrives without a pod replacement, and that the role and the app container are unchanged.

## Step 1: Read the current annotations

```sh
kubectl -n inventory get deployment inventory -o jsonpath='{.spec.template.metadata.annotations}' | jq
```

The first secret is injected with `agent-inject-secret-config.env`, the template annotation of the same name and the role. The name after `agent-inject-secret-` is the file name by default, so the second secret needs either the name `api.json` or a name of your choice plus `agent-inject-file-<name>`.

## Step 2: Add the three annotations

Edit the Deployment with `kubectl -n inventory edit deployment inventory` and add these under `spec.template.metadata.annotations`, next to the existing ones:

```yaml
vault.hashicorp.com/agent-inject-secret-api: "secret/data/inventory/api"
vault.hashicorp.com/agent-inject-file-api: "api.json"
vault.hashicorp.com/agent-inject-template-api: |
  {{- with secret "secret/data/inventory/api" -}}
  {
    "api_url": {{ .Data.data.api_url | toJSON }},
    "api_token": {{ .Data.data.api_token | toJSON }},
    "version": {{ .Data.metadata.version }}
  }
  {{- end }}
```

`api` is the unique name that ties the three annotations together. `agent-inject-file-api` names the file `api.json`. `toJSON` quotes and escapes the strings, and the version is written without quotes so it is a number.

## Step 3: Wait for the new pod and check

Annotations reach only new pods. The edit changes the pod template, so the Deployment rolls out a new pod:

```sh
kubectl -n inventory rollout status deployment/inventory
kubectl -n inventory exec deploy/inventory -c app -- ls /vault/secrets
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/api | jq .
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/config
```

## Step 4: Prove a new version arrives

```sh
bao kv patch secret/inventory/api api_token=changed-by-me
sleep 30
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/api | jq .
```

The `api_token` has the new value and `version` has gone up by one. The pod is the same, because the sidecar renders again every 15 seconds; the existing annotation `template-static-secret-render-interval` applies to every secret of the pod.

## Common mistakes

- Putting the annotations on the Deployment's own `metadata`. They must be on the pod template.
- Using different unique names in the three annotations, so the template is never applied to the secret.
- Removing the first secret's annotations while editing.
- Writing `"version": "{{ .Data.metadata.version }}"` with quotes. The grader needs a number.
