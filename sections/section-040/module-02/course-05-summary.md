# Summary

The annotations on a pod template are the injector's interface. The part of the name after the prefix is the unique name of one secret, and every annotation with that unique name shapes that secret's file.

## What you learned

`agent-inject-secret-<name>` names the secret path and creates a file; for KV version 2 the path includes `data/`. `agent-inject-file-<name>` sets the file name, `secret-volume-path` and `secret-volume-path-<name>` set the directory, and `agent-inject-containers` limits which containers see the volume. A second secret needs a second unique name.

Without a template, the output is the whole response in Go's map notation. `agent-inject-template-<name>` writes the template, `agent-inject-perms-<name>` sets the mode and `agent-inject-command-<name>` runs a command in the sidecar after a render. `template-static-secret-render-interval` sets how soon KV version 2 changes arrive.

Resources and limits are set with `agent-requests-*` and `agent-limits-*`. `agent-init-first` orders the agent before other init containers. `agent-pre-populate-only` removes the sidecar, `agent-inject-token` writes the token to a file and `agent-revoke-on-shutdown` revokes it on exit. `role`, `auth-path`, `namespace` and the TLS annotations decide how the agent logs in and connects, and mostly belong to the platform team. The key facts to remember are these:

- One unique name per secret, and the same name in all its annotations.
- Always write a template for KV version 2.
- Annotations reach only new pods.
- Keep the role narrow, because the annotation is the only thing between a pod and its policies.

<!-- astrona:playground:destroy -->
