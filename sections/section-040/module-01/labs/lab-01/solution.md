# Solution: Deliver Secrets To The Inventory Pods Without Code Changes

Work the task yourself first. Running `astrona submit -c sections/section-040/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks that the pod was injected, that the app serves the current secret, that a new version arrives within 90 seconds without a new pod, that the app container is unchanged, and that the role is scoped.

## Step 1: Create the role

Start the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), then:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
bao write auth/kubernetes/role/inventory \
  bound_service_account_names=inventory \
  bound_service_account_namespaces=inventory \
  token_policies=inventory-reader token_ttl=1h
```

Create the role before the annotations: the injected init container logs in as soon as the new pod starts.

## Step 2: Annotate the pod template

The annotations go on `spec.template.metadata.annotations`. Save this as `deployment-inventory.yaml`; only the `annotations` block is new:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: inventory
  labels:
    app: inventory
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
      annotations:
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
    spec:
      serviceAccountName: inventory
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d
      volumes:
        - name: nginx-conf
          configMap:
            name: nginx-conf
```

Apply it:

```sh
kubectl apply -f deployment-inventory.yaml
kubectl -n inventory rollout status deployment/inventory --timeout=240s
```

## Step 3: Check the result

```sh
kubectl -n inventory get pods -l app=inventory -o jsonpath='{.items[0].spec.initContainers[*].name} {.items[0].spec.containers[*].name}{"\n"}'
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/config
```

The pod lists `vault-agent-init`, `app` and `vault-agent`, and `/config` returns the three lines. If the pod stays in `Init:0/1`, read `kubectl -n inventory logs <pod> -c vault-agent-init`; a refused login points at the role.

## Step 4: Prove a new version arrives

```sh
bao kv patch secret/inventory/config api_key=lab-check
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.inventory/config
```

`API_KEY` shows the new value from the same pod. Without the render interval annotation, the sidecar would read the secret again only every five minutes.

## Step 5: Submit

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put the annotations on the Deployment's own `metadata` | Pods never get them; nothing is injected |
| Bind the role to `*` service accounts | Every pod in the cluster could read the inventory secrets |
| Add `agent-pre-populate-only: "true"` | The file is written once; the new version never arrives and the grader fails |
| Add a command to `nginx` that fetches the secret | Changes the app, and it would need a token |
