# Solution: Render The Inventory Configuration With OpenBao Agent

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass.

The grader checks four things: the app serves the current secret, a new secret version arrives without a pod restart, no token is stored in the pod or its ConfigMaps, and the role and policy are unchanged.

## Step 1: Read the agent's log

The app serves nothing, so start where the agent reports its work:

```sh
kubectl -n agent-demo logs deploy/inventory -c agent | tail -n 30
```

The auth handler fails again and again: OpenBao refuses the login for the role `inventory`. No token means no template runs.

## Step 2: Compare the role with OpenBao

List the roles and read the one meant for this app. This needs the port-forward (`kubectl -n openbao port-forward svc/openbao 8200:8200`) in a second terminal:

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
bao list auth/kubernetes/role
bao read auth/kubernetes/role/inventory-agent
```

The only role is `inventory-agent`, bound to the service account `inventory-agent` in `agent-demo`, which is the account the pod runs as. The configuration asks for `inventory`, a role that does not exist.

## Step 3: Compare the destination with the app

The app's `nginx` configuration says which file it serves:

```sh
kubectl -n agent-demo get configmap nginx-conf -o jsonpath='{.data.default\.conf}'
```

It serves `/etc/inventory/config.env`. The agent's template writes `/etc/inventory/config.txt`, so even a successful render would never reach the app.

## Step 4: Check the field paths

The template reads `.Data.db_host`. For a KV version 2 secret the fields are one level deeper, at `.Data.data.db_host`, so these lines would render as `<no value>`. The secret path itself, `secret/data/inventory/config`, is right.

## Step 5: Apply the fixed configuration

Save this as `configmap-agent-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-config
  namespace: agent-demo
data:
  agent.hcl: |
    vault {
      address = "http://openbao.openbao.svc:8200"
    }

    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "inventory-agent"
        }
      }

      sink "file" {
        config = {
          path = "/home/openbao/agent/token"
        }
      }
    }

    template_config {
      static_secret_render_interval = "15s"
    }

    template {
      destination = "/etc/inventory/config.env"
      contents    = <<EOT
    {{ with secret "secret/data/inventory/config" }}DB_HOST={{ .Data.data.db_host }}
    DB_USER={{ .Data.data.db_user }}
    API_KEY={{ .Data.data.api_key }}
    {{ end }}
    EOT
    }
```

Apply it, and restart the pod once so the agent reads the new file:

```sh
kubectl apply -f configmap-agent-config.yaml
kubectl -n agent-demo rollout restart deployment/inventory
kubectl -n agent-demo rollout status deployment/inventory
```

Then check the result:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
```

Three lines come back with the real values.

## Step 6: Prove a new version arrives

```sh
bao kv patch secret/inventory/config api_key=checked-by-hand
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agent-demo/config
```

`API_KEY` shows the new value, and `kubectl -n agent-demo get pods` shows the same pod as before. The 15 second render interval makes this fast; with the default of five minutes the grader's 90 seconds would not be enough.

## Step 7: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Change the role to accept the configuration's name, or bind `*` | Any pod could log in as this app; the grader checks the role |
| Put the root token into a `token_file` | The file renders, and anyone who can read the ConfigMap controls OpenBao |
| Change `nginx` to serve `config.txt` | It hides one fault and touches the application; the task says not to |
| Restart the pod after every secret change | The grader writes a new version and refuses an answer from a replaced pod |
