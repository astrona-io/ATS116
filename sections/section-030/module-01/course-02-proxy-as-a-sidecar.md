# Running The Proxy Next To The Application

A proxy that adds its token to every request has a dangerous property: anyone who can send it a request gets the proxy's access to OpenBao. If the proxy listened on the pod's network address, any pod in the cluster could read the inventory secrets through it, with no token of its own. This part shows how the playground prevents that, and what it takes to add a proxy to an application that has none.

The commands below need the port-forward in a second terminal (`kubectl -n openbao port-forward svc/openbao 8200:8200`), `BAO_ADDR=http://openbao.localtest.me:8200`, and the lab-only root token in `BAO_TOKEN`.

## One proxy per pod

A sidecar is a second container in the same pod as the application. Containers in one pod share a network namespace, so they reach each other on `127.0.0.1`, while nothing outside the pod can reach an address bound only to `127.0.0.1`. Check the containers of the `inventory` pod:

<!-- astrona:playground:renew -->

```sh
kubectl -n proxy-demo get deployment inventory -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"  "}{.image}{"\n"}{end}'
```

Two containers run in the pod: `proxy` with the OpenBao image and `app` with `nginx:1.27-alpine`. The proxy's `listener "tcp"` binds to `127.0.0.1:8100`, so only `app` can reach it. Prove that from outside the pod, using the pod's own address:

```sh
POD_IP="$(kubectl -n proxy-demo get pods -l app=inventory -o jsonpath='{.items[0].status.podIP}')"
kubectl -n clients exec deploy/tester -- curl -s --max-time 3 "http://$POD_IP:8100/v1/sys/health" || echo "connection refused"
```

The `tester` pod cannot connect: nothing listens on port 8100 at the pod's address. The Service `inventory` exposes only port `80`, the application. A proxy deployed as a shared Deployment with its own Service would answer here, and every pod that could reach that Service would act with the proxy's identity.

The sidecar pattern also gives each application its own identity. The proxy logs in with the pod's service account, so the `inventory` pod gets the `inventory-proxy` role and its policy, and another application with its own proxy gets its own role. Read the role to see that binding:

```sh
bao read auth/kubernetes/role/inventory-proxy
```

It binds exactly the service account `inventory-proxy` in the namespace `proxy-demo` to `inventory-reader`.

## Adding a proxy to an application

An application without a proxy needs four things. The order matters, because the proxy tries to log in as soon as it starts:

1. A service account for the pod, set as `serviceAccountName` in the pod template.
2. A Kubernetes auth role in OpenBao that binds that service account and namespace to a policy that allows only what the application reads.
3. A ConfigMap with the proxy configuration, with the listener on `127.0.0.1`.
4. A `proxy` container in the pod template, with the OpenBao image, `command: ["bao", "proxy", "-config=..."]`, and the ConfigMap mounted.

The application container itself does not change. It already sends its requests to `http://127.0.0.1:8100`; until the proxy runs, those requests fail to connect, and `nginx` answers `502`. A role is created with one command, for example:

```sh
bao write auth/kubernetes/role/<ROLE> \
  bound_service_account_names=<SERVICE_ACCOUNT> \
  bound_service_account_namespaces=<NAMESPACE> \
  token_policies=inventory-reader token_ttl=1h
```

Replace the three placeholders with the real names. Bind one service account in one namespace; a role with `*` in either field lets any pod log in as this application.

You now know why the proxy belongs inside the application's pod, how to prove that nothing else can reach it, and the four pieces that add a proxy to an application. The graded lab asks you to put those pieces together.

## Common pitfalls

> [!WARNING]
> - **Binding the listener to `0.0.0.0` or `[::]`.** Every pod that can reach the pod's address can then use the proxy's identity. Bind to `127.0.0.1`.
> - **Exposing the proxy port in the Service.** The Service is for the application. Port 8100 must not appear in it.
> - **Running one shared proxy for many applications.** All of them get the same identity and policies, and so does anything else that can reach it.
> - **Creating the role after the pod.** The proxy fails its first logins and retries; read its log after a fix before you decide it is still broken.

## Your mission: Serve Secrets To An App Through An OpenBao Proxy Sidecar

You can now run OpenBao Proxy as a sidecar that logs in with the pod's service account, and keep it reachable only inside the pod. The graded lab gives you an `inventory` app that already sends its requests to `127.0.0.1:8100` but has no proxy and no role, and asks you to add both without touching the app container.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-116-playground-030-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-030/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-116-lab-030-01
astrona start ats-116-playground-030-01
```
