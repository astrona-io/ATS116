# Solution: Serve Secrets To An App Through An OpenBao Proxy Sidecar

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks that the app returns the current secret through the proxy, that port 8100 is unreachable from another pod and absent from the Service, that the role is scoped, that the app container is unchanged, and that no token is stored in the pod.

## Step 1: Reach OpenBao

Start the port-forward in a second terminal, then set the address and the lab-only root token:

```sh
kubectl -n openbao port-forward svc/openbao 8200:8200
```

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
```

## Step 2: Create the role first

The proxy logs in as soon as it starts, so the role must exist before the proxy runs:

```sh
bao write auth/kubernetes/role/inventory-proxy \
  bound_service_account_names=inventory-proxy \
  bound_service_account_namespaces=proxy-demo \
  token_policies=inventory-reader token_ttl=1h
```

## Step 3: Write the proxy configuration

Save this as `configmap-proxy-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-config
  namespace: proxy-demo
data:
  proxy.hcl: |
    vault {
      address = "http://openbao.openbao.svc:8200"
    }

    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "inventory-proxy"
        }
      }
    }

    api_proxy {
      use_auto_auth_token = true
    }

    # Only containers in this pod can reach the proxy.
    listener "tcp" {
      address     = "127.0.0.1:8100"
      tls_disable = true
    }
```

Apply it:

```sh
kubectl apply -f configmap-proxy-config.yaml
```

## Step 4: Add the sidecar

Save this as `deployment-inventory.yaml`. The `app` container and its volume are exactly as they were; the `proxy` container and the `proxy-config` volume are new:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: proxy-demo
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
    spec:
      serviceAccountName: inventory-proxy
      containers:
        - name: proxy
          image: quay.io/openbao/openbao:2.7.1
          command: ["bao", "proxy", "-config=/etc/openbao-proxy/proxy.hcl"]
          volumeMounts:
            - name: proxy-config
              mountPath: /etc/openbao-proxy
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
        - name: proxy-config
          configMap:
            name: proxy-config
```

Apply it:

```sh
kubectl apply -f deployment-inventory.yaml
kubectl -n proxy-demo rollout status deployment/inventory
```

## Step 5: Check the result

The app returns the secret through the proxy, and the proxy cannot be reached from outside the pod:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxy-demo/config | jq '.data.data'
POD_IP="$(kubectl -n proxy-demo get pods -l app=inventory -o jsonpath='{.items[0].status.podIP}')"
kubectl -n clients exec deploy/tester -- curl -s --max-time 3 "http://$POD_IP:8100/v1/sys/health" || echo "connection refused"
```

If `/config` still answers `502`, read the proxy's log with `kubectl -n proxy-demo logs deploy/inventory -c proxy`; a failed login there points at the role.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Listen on `0.0.0.0:8100` | Any pod that reaches the pod's address reads the inventory secrets with no token |
| Bind the role to `*` service accounts | Any pod in the cluster can log in as this app |
| Add a `proxy_set_header X-Vault-Token` to `nginx` | Puts a token in a ConfigMap and changes the app; both are refused |
| Run one proxy Deployment with its own Service | Every pod that reaches the Service gets the proxy's identity |
