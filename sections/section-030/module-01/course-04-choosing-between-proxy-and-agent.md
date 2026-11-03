# Choosing Between Proxy And Agent

OpenBao Proxy and OpenBao Agent share the same code for logging in. Both run `auto_auth`, both can write the token to a sink and both can cache. They differ in what they do for the application. This part gives the questions that decide which one an application needs, and when it needs both.

## What each one does for the application

| | OpenBao Proxy | OpenBao Agent |
| --- | --- | --- |
| The application calls | An HTTP API address, with no token | A file the agent writes |
| The application needs to know | OpenBao's API paths and response shapes | Nothing about OpenBao |
| Secret changes reach the application | At the next request | At the next render, then the application must read the file |
| The agent or proxy holds | A token, and a cache of tokens and leases | A token, and the rendered files |
| Best for | Code that already calls the API, dynamic secrets on demand | Code that reads a configuration file or environment variables |

## Questions to ask

1. **Does the application already call OpenBao?** If it does, put a proxy next to it. The only change is the address and the removal of the token.
2. **Does the application read files or environment variables?** Use the agent with templates, or its exec mode. Changing a program to call an API is more work than rendering a file.
3. **Does it need a secret per request?** A fresh database credential for every job suits the API, so use the proxy. A password that changes once a day suits a rendered file.
4. **Can the application restart cheaply?** A rendered file can follow a secret without a restart. A program that reads its configuration only at start needs a reload command or a restart in either case.
5. **How many secrets and how many pods?** The agent reads each secret on a schedule from every pod. The proxy reads only what is asked.

## Using both

A pod can run both. The agent renders a configuration file for the framework, and the proxy answers the API calls the code makes for dynamic secrets. Each needs its own login and its own role, or both can use the same role. Give each only the policy it needs. Two sidecars are two processes to run and two logs to read, so do it only when the application needs both.

## What stays the same

Whichever you choose, the application has no token of its own. The sidecar logs in with the pod's identity. The role binds that identity to the least policy that works. The pod's other containers can reach the sidecar's listener or the files, so treat the whole pod as one trust boundary.

## Try it

For each of these applications, decide on proxy, agent or both, and write the reason in one sentence:

1. A legacy service that reads `/etc/app/db.properties` once a day.
2. A job that asks OpenBao for a new database credential at the start of each run.
3. A web service that reads a TLS certificate and key from disk and calls the API to sign each order.

Compare your answers with the table. The third needs both: a rendered certificate and API calls.

## Common pitfalls

> [!WARNING]
> - **Choosing the proxy for an application that cannot call HTTP.** It needs a file or a variable.
> - **Choosing the agent for an application that needs a new secret per request.** A file cannot do that.
> - **Giving both sidecars the same broad policy.** Each sidecar needs only its own paths.
> - **Running both when one is enough.** Every sidecar adds a process, a log and a failure to understand.
