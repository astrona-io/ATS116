# Solution: Move An App From A Static Token To OpenBao Proxy

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks that the app returns the secret, that the old token is revoked, that no token is stored in the pod or its ConfigMaps, that the proxy is reachable only inside the pod, that the role is scoped, and that the app container keeps its image and command.

## Step 1: Find out what the old token is

Start the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), then:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
OLD_TOKEN="$(kubectl -n proxycapstone get configmap nginx-conf -o jsonpath='{.data.default\.conf}' \
  | sed -n 's/.*X-Vault-Token "\([^"]*\)".*/\1/p')"
bao token lookup "$OLD_TOKEN"
```

The lookup shows an orphan token with the display name `inventory-static`, the policy `inventory-reader`, and a period: it is renewed forever as long as something uses it. Note its `accessor`. Do not revoke it yet; the app still depends on it.

## Step 2: Create the identity and the role

Save this as `serviceaccount-inventory-proxy.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inventory-proxy
  namespace: proxycapstone
```

Apply it, and create the role for it:

```sh
kubectl apply -f serviceaccount-inventory-proxy.yaml
bao write auth/kubernetes/role/inventory-proxy \
  bound_service_account_names=inventory-proxy \
  bound_service_account_namespaces=proxycapstone \
  token_policies=inventory-reader token_ttl=1h
```

## Step 3: Add the proxy and point nginx at it

Save this as `inventory-with-proxy.yaml`. It replaces `nginx-conf` (no token header, upstream `127.0.0.1:8100`), adds `proxy-config`, and adds the sidecar and the service account to the Deployment. The `app` container is unchanged:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-config
  namespace: proxycapstone
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
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
  namespace: proxycapstone
data:
  default.conf: |
    server {
      listen 80;
      location = /config {
        proxy_pass http://127.0.0.1:8100/v1/secret/data/inventory/config;
      }
      location = /healthz {
        return 200 "ok";
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  namespace: proxycapstone
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
kubectl apply -f inventory-with-proxy.yaml
kubectl -n proxycapstone rollout status deployment/inventory
```

Then check that the app works through the proxy before you touch the old token:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.proxycapstone/config | jq '.data.data.db_host'
```

## Step 4: Revoke the old token

Only now, with the app on the proxy, revoke the old token. Revoking by token value works; revoking by accessor works too and avoids handling the token again:

```sh
bao token revoke "$OLD_TOKEN"
```

Ask the app once more; it still answers, because it no longer uses that token.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Revoke the token first | The app breaks until the proxy runs; in production that is an outage |
| Move the token to a Kubernetes Secret | It is still a long-lived token readable by anyone with access to that Secret |
| Keep the old token "as a fallback" | The finding stays open; the grader requires it revoked |
| Bind the role to the `default` service account | Every pod in the namespace without its own account gets the inventory secrets |
