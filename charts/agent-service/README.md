# agent-service

Public AI's sovereign agent API, two planes in one chart — ported from agent-service's own
`deploy/k8s/*.yaml` raw manifests as a faithful template, not a redesign:

- **agent-proxy** (Plane A) — the model-boundary gateway. Holds the real model credential, the only
  pod with egress to the upstream model endpoint.
- **agent-app** (Plane B) — per-task execution. Credential-free; gets a per-task nonce from the proxy,
  runs the sandboxed agent loop, stores results on a PVC.

See agent-service's own `deploy/README.md` for the design rationale behind the split.

## Before first sync

Two Secrets must exist in the target namespace before this chart is installed — it references
them (`envFrom.secretRef`). With ESO enabled (`externalSecret.enabled: true`), the chart automatically
creates `ExternalSecret` resources to pull secrets from AWS Secrets Manager via `ClusterSecretStore` (default `/agent-service`).

If managing secrets manually instead:
- `agent-app` (or your override of `app.secretName`) — needs `PROXY_ADMIN_KEY`, `WEBUI_SECRET_KEY`
- `agent-gateway` (or your override of `proxy.secretName`) — needs `PROVIDER_CSCS_TOKEN`,
  `PROXY_ADMIN_KEY` (must match the app's copy)

See agent-service's own `deploy/k8s/secret.example.yaml` for the full shape — never commit real values
anywhere, including here.

**NetworkPolicy enforcement is not guaranteed.** This chart ships a default-deny-egress NetworkPolicy
that is the actual control stopping the sandboxed per-task agent from exfiltrating data anywhere but the
proxy. Stock EKS with the default AWS VPC CNI does *not* enforce NetworkPolicy objects unless the VPC
CNI's network-policy feature (or Calico/Cilium) is explicitly enabled. Confirm enforcement is live
before trusting this: a scratch pod in the namespace attempting egress to an arbitrary external IP
should be blocked.

## Values

| Key                                  | Description                                                                                                                     | Default                          |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| `image.repository`                    | Container image repo                                                                                                              | `ghcr.io/REPLACE_ME/agent-service` |
| `image.tag`                           | Container image tag — `:latest` defeats staging→production promotion (nothing to diff or roll back); real per-commit tags need to come from agent-service's own CI | `latest`                          |
| `image.pullPolicy`                    |                                                                                                                                     | `IfNotPresent`                    |
| `app.replicas` / `proxy.replicas`     | **Must stay 1** — enforced by `values.schema.json` (`maximum: 1`). The SQLite task store and in-memory concurrency/admin caps are per-pod state | `1`                                |
| `app.port` / `proxy.port`             | Container ports                                                                                                                   | `8731` / `8732`                   |
| `app.pvcSize`                         | Task-store PVC size                                                                                                               | `1Gi`                              |
| `app.secretName` / `proxy.secretName` | Pre-existing Secret name each Deployment references (see "Before first sync")                                                    | `agent-app` / `agent-gateway`     |
| `app.env` / `proxy.env`               | Flat key/value env vars merged onto each Deployment                                                                               | see `values.yaml`                 |
| `app.resources` / `proxy.resources`   | Standard Kubernetes resource requests/limits                                                                                      | see `values.yaml`                 |
