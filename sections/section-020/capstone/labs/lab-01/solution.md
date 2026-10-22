# Solution: Log The Agent In With AppRole And Keep The File Fresh

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass.

The grader checks that the app serves the current secret, that a new version arrives within 90 seconds without a pod restart, that no token is stored in the pod or its ConfigMaps, and that `batch-reader` is narrow. There are three independent faults; fix them one at a time and read the agent's log after each.

## Step 1: The agent cannot read its role ID

```sh
kubectl -n agentcapstone logs deploy/inventory -c agent | tail -n 30
```

The AppRole method cannot read its role ID file. Compare the file names the Secret provides with the paths in the configuration:

```sh
kubectl -n agentcapstone exec deploy/inventory -c agent -- ls /etc/approle
kubectl -n agentcapstone get configmap agent-config -o jsonpath='{.data.agent\.hcl}' | grep file_path
```

The mounted files are `role-id` and `secret-id`, named after the Secret's keys. The configuration reads `/etc/approle/role_id`, with an underscore. `remove_secret_id_file_after_reading = false` is correct here: the files come from a read-only Secret volume, and the agent must not try to delete them.

## Step 2: The token may not read the secret

After the path is fixed and the pod restarted, the agent logs in, but the render fails with `permission denied`. Read the policy (with the port-forward running and the lab-only root token in `BAO_TOKEN`):

```sh
export BAO_ADDR=http://openbao.localtest.me:8200
export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"
bao policy read batch-reader
```

The rule names `secret/data/inventory/configs`, with an extra `s`. Policies match paths exactly, so the read of `secret/data/inventory/config` is denied. Note that a policy needs the full `data/` path even though a template may leave it out.

Save this as `policy-batch-reader.hcl`:

```hcl
# Read the inventory configuration.
path "secret/data/inventory/config" {
  capabilities = ["read"]
}
```

Write it:

```sh
bao policy write batch-reader policy-batch-reader.hcl
```

## Step 3: New versions arrive only every ten minutes

Now the file renders, but a new `api_key` takes far longer than a minute to appear. The configuration sets `static_secret_render_interval = "10m"`, so the agent reads the KV version 2 secret again only every ten minutes.

## Step 4: Apply the fixed configuration

Save this as `configmap-agent-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: agent-config
  namespace: agentcapstone
data:
  agent.hcl: |
    vault {
      address = "http://openbao.openbao.svc:8200"
    }

    auto_auth {
      method "approle" {
        mount_path = "auth/approle"
        config = {
          role_id_file_path                   = "/etc/approle/role-id"
          secret_id_file_path                 = "/etc/approle/secret-id"
          remove_secret_id_file_after_reading = false
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

Apply it and restart the pod once:

```sh
kubectl apply -f configmap-agent-config.yaml
kubectl -n agentcapstone rollout restart deployment/inventory
kubectl -n agentcapstone rollout status deployment/inventory
```

Then check the result, including a new version:

```sh
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agentcapstone/config
bao kv patch secret/inventory/config api_key=capstone-check
sleep 20
kubectl -n clients exec deploy/tester -- curl -s http://inventory.agentcapstone/config
```

## Step 5: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Rename the Secret's keys to `role_id` | The task forbids changing the Secret; the configuration is the thing that is wrong |
| Grant `secret/data/*` in `batch-reader` | The batch team could read every secret in the engine; the grader refuses it |
| Add a `token_file` with the root token | The file renders, and the pod now holds full control of OpenBao |
| Restart the pod every few minutes | Hides the render interval; the grader refuses an answer from a replaced pod |
