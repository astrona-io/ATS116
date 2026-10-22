# Section 010: The OpenBao HTTP API

Every OpenBao client talks to the server through the same HTTP API: the `bao` command-line tool, OpenBao Agent, OpenBao Proxy and the Kubernetes injector all send HTTP requests under `/v1/`. When one of them fails, the fastest way to find out why is often to send the same request yourself with `curl` and read the answer.

This section teaches that API directly. It comes first because every later section builds on it: an agent template reads a path, a proxy forwards a request, and an injected sidecar logs in, and each of those is an HTTP request you can reproduce.

## What you will learn

- The shape of a request: the `/v1/` path, the method, and the `X-Vault-Token` header.
- The shape of a response: `data`, `auth`, `lease_duration`, `wrap_info`, `warnings`, and the `errors` list with its status code.
- Logging in over HTTP with userpass and AppRole, and using the token you get back.
- Reading, writing and listing KV version 2 secrets, and why their paths contain `data/` and `metadata/`.
- Asking OpenBao to wrap a response, and looking up or unwrapping a wrapping token.

## The learning path

The module starts at its landing page, which also launches the playground. The playground holds OpenBao with the user `deployer`, the AppRole `report`, and three secrets under `secret/inventory/`.

### 1. Talk To OpenBao Over HTTP

1. Requests, Tokens And Responses
2. Logging In, Reading, Writing And Listing
3. Response Wrapping And Request Headers, followed by the lab **Hand Over A Secret With A Wrapped Response**
4. Summary

## Section capstone: Repair A Script That Calls The OpenBao API

The capstone is one graded scenario that combines the whole module. A reporting Job in the namespace `apicapstone` logs in with AppRole, lists the inventory secrets and prints each one, and it fails on every run. Read its HTTP answers, fix the script, and prove it with a run that reports every secret. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-116-capstone-010
```
