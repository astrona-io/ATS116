# Solution: Repair Secret Injection For The Inventory App

Work the task yourself first. Running `astrona submit -c sections/section-040/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks that the pod is injected, that the app serves the current secret, that a new version arrives without a new pod, that the app container is unchanged, and that the role is scoped. Three faults stand in the way, and each hides the next one.

## Step 1: Was the pod injected?

```sh
POD="$(kubectl -n injectcapstone get pods -l app=inventory -o jsonpath='{.items[0].metadata.name}')"
kubectl -n injectcapstone get pod "$POD" -o jsonpath='status={.metadata.annotations.vault\.hashicorp\.com/agent-inject-status} containers={.spec.containers[*].name}{"\n"}'
```

There is no status and only the `app` container: the injector never changed this pod. Look at where the annotations are:

```sh
kubectl -n injectcapstone get deployment inventory -o jsonpath='deployment: {.metadata.annotations}{"\n"}pod template: {.spec.template.metadata.annotations}{"\n"}'
```

They are on the Deployment's own `metadata`, and the pod template has none. Kubernetes never copies Deployment annotations to pods, so the injector never saw them. This is the first fault.

## Step 2: Fix the role

Start the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), then compare the role with the pod's service account:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
kubectl -n injectcapstone get deployment inventory -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
bao read auth/kubernetes/role/inventory
```

The pods run as `inventory`, but the role binds `inventory-app`. Once the pod is injected, its init container would be refused at every login and the pod would stay in `Init:0/1`. Fix the role now, before the new pod starts:

```sh
bao write auth/kubernetes/role/inventory \
  bound_service_account_names=inventory \
  bound_service_account_namespaces=injectcapstone \
  token_policies=inventory-reader token_ttl=1h
```

## Step 3: Move the annotations and fix the template

The template in the annotations reads `.Data.db_host`. For a KV version 2 secret the fields are at `.Data.data.db_host`; the old template would render `<no value>` on every line. Save this as `deployment-inventory.yaml`, with the annotations on the pod template and the corrected template:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: injectcapstone
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

This file has no annotations on the Deployment's own `metadata`. `kubectl apply` removes the old ones, because it applied them in the first place. Apply it:

```sh
kubectl apply -f deployment-inventory.yaml
kubectl -n injectcapstone rollout status deployment/inventory --timeout=240s
```

## Step 4: Check the result

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.injectcapstone/config
bao kv patch secret/inventory/config api_key=capstone-check
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.injectcapstone/config
```

The first answer shows the three lines; the second shows the new `api_key` from the same pod.

## Step 5: Submit

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Change the pods to run as `inventory-app` | The task keeps the service account; fix the role instead |
| Bind the role to both service accounts, or to `*` | More pods than the app can read the secrets; the grader checks the binding |
| Remove the template annotation | The file is written in the default format, not the three lines the app needs |
| Fix only the annotations' location | The init container is then refused at every login and the pod never starts |
