# Section 040: The Kubernetes Agent Injector

Running OpenBao Agent as a second container works, but every team then writes the same container, the same volumes and the same configuration into every Deployment. The agent injector does that work for them. It is a Kubernetes admission webhook: when a pod is created with the right annotations, it adds an OpenBao Agent init container and sidecar to the pod, writes their configuration from the annotations, and mounts a shared volume where the secrets appear.

This section uses the injector that the `openbao` Helm chart installs. Its names still say `vault`, and the section explains why before you meet them.

## What you will learn

- What runs: the injector Deployment, the mutating webhook, and the OpenBao Agent image it injects.
- Why the annotations start with `vault.hashicorp.com/` and the secrets appear in `/vault/secrets`.
- The annotations for secrets, templates, the role and the render interval, and where on a Deployment they belong.
- The init container and the sidecar, and `agent-pre-populate-only`.
- Finding out why a pod was not injected, or why its init container never finishes.

## The learning path

The module starts at its landing page, which also launches the playground. The playground runs the `inventory` app in the namespace `inventory` with injection working.

### 1. Deliver Secrets To Pods With The Agent Injector

1. How The Agent Injector Works
2. Annotations And Templates, followed by the lab **Deliver Secrets To The Inventory Pods Without Code Changes**
3. Troubleshooting Injection
4. Summary

## Section capstone: Repair Secret Injection For The Inventory App

The capstone is one graded scenario that combines the whole module. In the namespace `injectcapstone`, the `inventory` app has every annotation it needs and still gets no secrets. Find each reason, fix the Deployment and the role without changing the application, and prove that a new secret version reaches the app. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-116-capstone-040
```
