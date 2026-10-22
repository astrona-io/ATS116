# Welcome To The Course

This course trains you for the **OpenBao Agent, Proxy & Application Integration** part of the Astrona **OpenBao** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, ConfigMaps, Secrets, service accounts, `kubectl logs` and `kubectl exec`. You have used `curl` to call an HTTP API and you can read JSON. You know what OpenBao is for and what a token, a policy and a KV secret are; each page repeats the facts it needs in a sentence. Each new idea is explained the first time it appears.

## What you can do at the end

Storing a secret in OpenBao is half the work. The other half is getting it into the application that needs it, without putting a long-lived token next to it. This course is about that second half. It asks you to deliver a secret to a running application, prove the application sees it, and prove the application sees a new version when the secret changes. The course has four topics.

The first topic is **the HTTP API**, the interface every OpenBao client uses. You will learn to:

- Send authenticated requests with the `X-Vault-Token` header, and read responses and errors.
- Log in, read, write and list KV version 2 secrets over HTTP.
- Hand a secret to someone else as a single-use wrapping token.

The second topic is **OpenBao Agent**, a process that runs next to your application. You will learn to:

- Let the agent log in on its own with auto-auth, using the pod's Kubernetes service account or an AppRole.
- Render secrets into a file with a template, and render it again when the secret changes.
- Pass secrets to a program as environment variables.

The third topic is **OpenBao Proxy**. You will learn to:

- Let an application call OpenBao without any token of its own.
- Keep the proxy reachable only from inside its own pod.
- Understand which tokens and leases the proxy caches.

The fourth topic is **the Kubernetes agent injector**. You will learn to:

- Add the agent to a pod with annotations, without changing the application's image or command.
- Find out why a pod was not injected, or why its agent never finishes.

Everything is written for **OpenBao v2.7.1**.

## The words this course uses

The pages use OpenBao's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **token** is the credential OpenBao checks on every request. A **policy** lists the paths a token may use and what it may do there. **Auto-auth** is how the agent or the proxy logs in on its own, with a **method** such as the Kubernetes auth method. A **template** describes how the agent writes a secret into a file. Some names in this course still say `vault`, such as the `X-Vault-Token` header and the injector's `vault.hashicorp.com/` annotations. OpenBao started as a fork of Vault and keeps those names so existing tools keep working.

Four ways to deliver a secret appear in the course, and each fits a different application:

| Way | The application... |
| --- | --- |
| HTTP API | ...calls OpenBao itself and handles its own token |
| OpenBao Agent | ...reads a file (or environment variables) that the agent keeps up to date |
| OpenBao Proxy | ...calls OpenBao through a local proxy that adds the token |
| Agent injector | ...reads a file; Kubernetes adds the agent from annotations |

## The example setup in your playground

Every playground and lab runs OpenBao 2.7.1 in the namespace `openbao`, already initialized and unsealed. It holds one secret, `secret/inventory/config`, with the fields `db_host`, `db_user` and `api_key`. The example application, `inventory`, is an `nginx` web server that serves its configuration at the address `/config`. You change how the secret reaches it, never the application itself. A `tester` pod in the namespace `clients` sends test requests.

The lab-only root token is stored in a Kubernetes Secret called `openbao-init`, so you can always run administrator commands. A real installation never keeps the root token there. Many labs start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has four sections, from the most direct way to deliver a secret to the most automatic one.

| Section | What it covers |
| --- | --- |
| 010 | The OpenBao HTTP API |
| 020 | OpenBao Agent |
| 030 | OpenBao Proxy And Caching |
| 040 | The Kubernetes Agent Injector |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
