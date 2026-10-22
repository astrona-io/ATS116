# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS116 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **OpenBao Agent, Proxy & Application Integration**
  domain of the **OpenBao** training path (`ATP022`). It is 15% of the path.
  There is no official OpenBao certification exam; the path's domains and
  weights are Astrona's own, set in `ATP022/path.yaml`.
- **What the domain really tests:** getting secrets into applications without
  putting tokens or OpenBao calls into the application: call the HTTP API
  directly when you must, run OpenBao Agent to authenticate and render files,
  run OpenBao Proxy so an application calls OpenBao without a token, and let
  the Kubernetes agent injector add the agent to pods from annotations. Every
  explanation should lead to a command the reader can run, and every fix
  should be proved with an application that serves the rendered secret and
  picks up a new secret version.
- **The four topics:** the HTTP API, OpenBao Agent (auto-auth, sinks,
  templates, process supervisor mode), OpenBao Proxy (API proxy and caching),
  and the Kubernetes agent injector.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | The OpenBao HTTP API | HTTP API |
  | 020 | OpenBao Agent | Agent |
  | 030 | OpenBao Proxy And Caching | Proxy |
  | 040 | The Kubernetes Agent Injector | Injector |

- **The versions:** **OpenBao v2.7.1** (server, agent, proxy and the `bao`
  CLI), the `openbao` Helm chart **0.30.4** and Helm **3.22.1** on a
  single-node `kind` cluster. The injector is **`hashicorp/vault-k8s:1.7.6`**
  (the chart default, see below). Do not teach fields, flags or output from
  other versions without saying so.
- **The main sources:** <https://openbao.org/docs/> (agent-and-proxy,
  platform/k8s, api, auth/kubernetes), the source of `openbao/openbao` at tag
  `v2.7.1` (docs under `website/content/docs/`), the chart 0.30.4 values, and
  the source of `hashicorp/vault-k8s` at tag `v1.7.6` for every injector
  annotation.

### The injector: what really runs (read before touching section 040)

These facts were read from the sources, not the docs pages, and they decide
every injector example:

- **The chart deploys HashiCorp's injector.** `openbao` chart 0.30.4 sets
  `injector.image` to `docker.io/hashicorp/vault-k8s:1.7.6` and
  `injector.agentImage` to `quay.io/openbao/openbao` (tag = chart
  `appVersion`). The `openbao/openbao-k8s` project has git tags (v1.4.0) but
  **publishes no image** on quay.io, ghcr.io or Docker Hub (checked
  2026-10-22). This repository pins both images explicitly in
  `injector-values.yaml`.
- **The annotation prefix is `vault.hashicorp.com/`.** Both vault-k8s 1.7.6
  and openbao-k8s v1.4.0 use it in their source. The OpenBao injector docs
  page (`platform/k8s/injector/index.mdx`, marked `draft: true`) shows
  `openbao.openbao.com/...` and `/openbao/secrets`; no released injector
  uses either. Teach `vault.hashicorp.com/...` and `/vault/secrets`, and say
  once, plainly, why the names still say `vault`.
- **The agent runs as `vault agent`.** vault-k8s starts the agent container
  with `vault agent -config=/home/vault/config.json`. The OpenBao image ships
  `ln -s /usr/bin/bao /usr/bin/vault` for this reason, so the process is
  OpenBao Agent v2.7.1. The agent runs as user `100`.
- **Secrets land in `/vault/secrets/<name>`**, a shared in-memory volume
  mounted into every container of the pod.
- **Template paths without `data/` still work.** `openbao-template` v1.0.1
  (the version in OpenBao 2.7.1) detects a KV version 2 mount and inserts
  `data/` itself (`shimKVv2Path` in `dependency/vault_read.go`). Never teach a
  missing `data/` as a template fault; it is a fault only in raw HTTP requests
  and in policies.
- **KV version 2 re-renders every 5 minutes by default.** Labs set
  `template_config { static_secret_render_interval = "15s" }` in agent and
  proxy configurations, and the annotation
  `vault.hashicorp.com/template-static-secret-render-interval: "15s"` for
  injected pods, so a grader sees a new version within a minute.

### Status: built, not yet run

The first version of this repository was written from the OpenBao 2.7
documentation and source **without a live run**. No playground or lab has
been started, and no `astrona test` has passed yet. Until a maintainer runs
them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

Ranked risks for the first run:

1. The injector: vault-k8s 1.7.6 injecting the OpenBao 2.7.1 image (the
   `vault` symlink, `/home/vault` written by user `100`, the JSON agent
   config it generates being accepted by OpenBao Agent).
2. `kubernetes_host=https://kubernetes.default.svc:443` with no reviewer JWT:
   OpenBao uses its own pod's service account token and CA for TokenReview.
3. Agent and Proxy containers started with `command: ["bao", ...]`, bypassing
   the image entrypoint, writing to `emptyDir` volumes as user `openbao`.
4. Re-render timing: graders wait up to 90 seconds for a new KV version.

### Terms, not metaphors

| Term | First-use definition (example wording) |
| --- | --- |
| HTTP API | OpenBao's REST interface under `/v1/`; the CLI, the agent and the proxy all use it |
| `X-Vault-Token` | The request header that carries the token (`Authorization: Bearer` also works); the name is kept from Vault for compatibility |
| `LIST` | The HTTP verb (or `?list=true`) that returns the keys under a path |
| Response wrapping | OpenBao puts a response in a single-use cubbyhole and returns a wrapping token instead; requested with the `X-Vault-Wrap-TTL` header |
| OpenBao Agent | A client daemon (`bao agent`) that authenticates, keeps its token renewed, and renders secrets into files or environment variables |
| Auto-auth | The agent's login loop: a `method` (for example `kubernetes` or `approle`) gets a token, `sink`s write it to files |
| Sink | Where auto-auth writes the token, for example `sink "file"` |
| Template | A `template` stanza: a source or inline `contents` in the template language, rendered to a `destination` file |
| `template_config` | Global template settings, for example `static_secret_render_interval` and `exit_on_retry_failure` |
| Process supervisor mode | The agent runs a child process (`exec`) with secrets as environment variables (`env_template`) and restarts it when they change |
| OpenBao Proxy | A client daemon (`bao proxy`) that forwards API requests to OpenBao, adds its auto-auth token (`api_proxy`), and caches tokens and leases (`cache`) |
| Agent injector | A Kubernetes mutating admission webhook that adds an init container and a sidecar running the agent to pods with `vault.hashicorp.com/agent-inject: "true"` |
| Kubernetes auth method | Logs a pod in with its service account token; a role binds service account names and namespaces to policies |

### The example workloads

| Name | What it is |
| --- | --- |
| OpenBao (namespace `openbao`) | OpenBao v2.7.1 as in ATS112: pod `openbao-0`, Service `openbao` port `8200`, Raft storage, no TLS (lab-only). Every environment starts initialized and unsealed (`INIT_MODE=unsealed`); the lab-only unseal key and root token are in Secret `openbao-init` |
| KV version 2 at `secret/` | Seeded with `secret/inventory/config` (`db_host`, `db_user`, `api_key`) |
| Kubernetes auth at `auth/kubernetes` | Configured with `kubernetes_host=https://kubernetes.default.svc:443` |
| `tester` (namespace `clients`) | `nicolaka/netshoot:v0.13`, `curl` and `jq`; graders call the API from here |
| `inventory` app | `nginx:1.27-alpine` that serves a rendered file at `/config`. Its image and command never change: that is the "zero code change" the course proves |
| Injector (sections 040) | `openbao-agent-injector` Deployment in `openbao`, images pinned in `manifests/injector-values.yaml` |

### Environment facts the text must respect

- **One address everywhere: `http://openbao.localtest.me:8200`**, exactly as
  in ATS112 (CoreDNS `rewrite stop` block plus a port-forward). Copy the block
  from `sections/section-010/module-01/playground/bootstrap/prepare.sh`; never
  the one-line `rewrite name` form. Inside application pods, agents and
  proxies use `http://openbao.openbao.svc:8200`.
- **The reader's root token is lab-only.** Pages fetch it with
  `export BAO_TOKEN="$(kubectl -n openbao get secret openbao-init -o jsonpath='{.data.root-token}' | base64 -d)"`
  and say that a real installation never keeps it in a Kubernetes Secret.
- **No token ever goes into an application pod's spec.** Agents and proxies
  log in with the pod's service account (or AppRole files in one capstone).
  Graders reject a token in an environment variable, a ConfigMap or a
  `token_file` method.
- **Agent and proxy containers** use `quay.io/openbao/openbao:2.7.1` with
  `command: ["bao", "agent", "-config=..."]` or `["bao", "proxy", ...]`.
- **Many environments start broken on purpose** (a wrong role, a template
  field at `.Data.x` instead of `.Data.data.x`, an annotation in the wrong
  place). The fault is the
  material. Never "fix" it in the bootstrap.

### Where things are in this repo

The layout is the same as every Astrona course: `astrona.yaml`, `README.md`,
`sections/intro/`, `sections/section-0N0/README.md`, module pages
(`course.md`, `course-0N-*.md`), `playground/` (`config.yaml`,
`bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`), labs
(`config.yaml`, `README.md`, `prerequisites.md`, `question.md`,
`solution.md`, `bootstrap/01-install-openbao.sh`,
`bootstrap/02-seed-state.sh`, `manifests/`, `solution/apply.sh`,
`testing/wait-for-openbao.sh`, `validation/validate-*.sh`) and one capstone
per section.

The plumbing of every environment (bootstrap, seed, testing, solution and
validation scripts, `config.yaml`, author READMEs, `prerequisites.md`) was
generated from one Python generator kept outside the repository. Shared
pieces (the install script, the `bao_root` and `api_get` helpers, the
CoreDNS block) are copied into every environment: change them in **every**
environment at once.

### Lab metadata in `astrona.yaml`

`training:` block: id `ATS116`, domain `OpenBao Agent, Proxy & Application
Integration`, weight `15`. Lab entries carry `title`, `path`, `difficulty`,
`estimated_duration`, `topic`, `task_kind`, `tags`, `learning_goals`,
`resources`, in that order, as in ATS016.

- `topic`: exactly one of `http-api`, `agent`, `templates`, `proxy`,
  `caching`, `injector`.
- `task_kind`: `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8, only from this list: `http-api`, `x-vault-token`,
  `list-verb`, `kv-v2`, `response-wrapping`, `userpass`, `approle`,
  `kubernetes-auth`, `auto-auth`, `file-sink`, `agent-template`,
  `template-config`, `env-template`, `exec`, `api-proxy`, `cache`,
  `bao-proxy`, `sidecar`, `agent-injector`, `annotations`,
  `pre-populate`, `service-account`, `policy`, `zero-code-change`.
- `resources`: 1 to 4 pages on `openbao.org`. The only place outside links
  are allowed.

### Running things

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-010/module-01/playground
astrona destroy ats-116-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS116.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-116-lab-010-01
astrona test -c sections/section-010/module-01/labs/lab-01   # authors
```

Names: `ats-116-playground-<section>-<module>`, `ats-116-lab-<section>-<module>`,
`ats-116-capstone-<section>`. Graders check **behaviour** (the app serves the
rendered secret, a new KV version shows up, a request through the proxy works
without a token, the old static token is revoked) and reject the plausible
but wrong fix (putting the root token or any token into the pod, granting
the app's policy `*` capabilities, changing the app image or command,
binding a role to every service account with `*`). A lab's `question.md` and
`solution.md` must match what its `validation/` scripts check.

### Where to find trusted sources

- **HTTP API:** <https://openbao.org/docs/api/>
- **Agent:** <https://openbao.org/docs/agent-and-proxy/agent/>, its
  template, process supervisor and API proxy pages, and
  <https://openbao.org/docs/agent-and-proxy/autoauth/>
- **Proxy:** <https://openbao.org/docs/agent-and-proxy/proxy/> and its
  caching pages
- **Kubernetes:** <https://openbao.org/docs/platform/k8s/injector/>,
  <https://openbao.org/docs/platform/k8s/helm/>,
  <https://openbao.org/docs/auth/kubernetes/>
- **Injector annotations (exact names):** `agent-inject/agent/annotations.go`
  in `hashicorp/vault-k8s` at tag `v1.7.6`
