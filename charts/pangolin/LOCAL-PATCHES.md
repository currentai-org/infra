# charts/pangolin — local patches vs. upstream

Vendored from [`fosrl/helm-charts`](https://github.com/fosrl/helm-charts), tag `pangolin-0.1.0-alpha.1`
(commit `5acaf16c6e2841664668b2c5b044484dcbd0a5b9`), full `charts/pangolin` subtree copied verbatim,
then patched. This document is the diff-vs-upstream summary for re-basing on a future upstream bump —
read it before touching anything in this directory, and update it in the same PR as any further patch.

Written for CUR-1266's "managed" local-inference endpoint kind (a user's llama.cpp server, reached
through a Pangolin tunnel). The companion plan document has the full staging rollout design,
hostnames, and rollout order; this file is scoped to *what differs from upstream and why*.

**If you don't already know what Pangolin does or why this chart is shaped the way it is, read
`pangolin/ARCHITECTURE.md` in the `aipotluck.org` repo first.** It has the system map and two
sequence diagrams (pairing a device, serving one inference request), and explains the two constraints
that drive most of the decisions below: the three containers must share a network namespace (which is
why `deployment.mode: single`), and there are three distinct network paths whose hostnames are easy to
confuse. This file assumes that context.

## Why vendor instead of referencing the chart remotely

The repo's own convention (see `../../README.md`) is to hand-write charts, and the original design
pass for this work considered referencing `fosrl/helm-charts`'s published chart directly via a
multi-source ArgoCD Application instead of vendoring it — less to maintain, no local diff to carry.
That doesn't work here: the chart needs a real patch to route any traffic at all in the deployment
mode this repo can support (B1 below), and a multi-source Application can't apply a patch to a remote
chart's templates. Vendoring from **git**, not the release tarball, was deliberate too — the git tree
carries the chart's own `tests/` suite (a real `helm unittest` corpus, 27 files, ~400 assertions), so
our patch stays covered by upstream's own regression tests rather than an untested black box.

## B1 — standalone Traefik cannot route per-device traffic as shipped

**File patched:** `templates/deployment-single.yaml` (the Traefik container block).

Upstream wires `--providers.kubernetescrd` and `--providers.kubernetesingress` into every Traefik
container it starts, in both `templates/deployment-traefik.yaml` (the `deployment.mode=multi`
template) and `templates/deployment-single.yaml` (the `mode=single` template this repo actually
renders — see "deployment.mode: single, not multi" below for why). Those two providers only ever
produce routers under `deployment.type=controller` — that's the only mode `templates/rbac.yaml`
grants Traefik's ServiceAccount *any* RBAC at all (`rbac.yaml:3-4`: `$renderController := and
.Values.controller.enabled (eq .Values.deployment.type "controller")`). Under our
`standalone`/`single` deployment, those two providers have no RBAC, watch CRDs we never install
(no cluster-wide Traefik CRDs — out of scope, see "Why standalone, not controller" below), and —
more importantly — are simply the wrong mechanism regardless of RBAC: Pangolin programs per-device
tunnel routes itself and expects Traefik to pull them from its own HTTP API
(`GET /api/v1/traefik-config` on Pangolin's internal-api port), enforced by the `badger` Traefik
plugin, which checks each request's resource access token. Neither the HTTP provider nor the plugin
exists anywhere in the upstream template for any deployment shape this repo can run. Without this
patch, standalone/single mode renders a Traefik that starts, passes its own health probe (once
combined with the fix below), and routes *nothing* — every per-device hostname 404s forever.

The patch removes the two unusable Kubernetes providers and adds:

```
--entrypoints.traefik.address=:{{ $tf.config.adminPort | default 8085 }}
--providers.http.endpoint=http://127.0.0.1:{{ $root.Values.pangolin.service.ports.internalApi | default 3001 }}/api/v1/traefik-config
--providers.http.pollInterval=5s
--experimental.plugins.badger.moduleName=github.com/fosrl/badger
--experimental.plugins.badger.version=v1.4.1
```

`127.0.0.1` is deliberate, not a placeholder: under `deployment.mode=single` the pangolin, gerbil,
and traefik containers share one Pod (and therefore one network namespace), and the chart's own
gerbil container already talks to Pangolin's internal API the same way
(`--remoteConfig=http://127.0.0.1:3001/api/v1/`, see `deployment-single.yaml`'s gerbil `args`) — this
patch just does the same thing for Traefik.

The `--entrypoints.traefik.address` line matters independently of routing: the chart's shipped
readiness/liveness probes target port 8085 via Traefik's `--ping=true`, but ping binds to an
entrypoint literally named `traefik` by default, and nothing in the upstream args ever creates one.
Without this line the shipped probes can never pass, chart-wide, regardless of B1's routing fix —
confirmed by reading Traefik's own `--ping` documentation and corroborated by the mismatch between
the probe's target port and the args list.

This mirrors what CUR-1266's local Docker Compose stack already does
(`aipotluck.org/pangolin/config/traefik/traefik_config.yml`), translated from Traefik's static-config
YAML syntax to the CLI-args form this chart's Deployment templates use.

**Not patched (deliberately): `templates/deployment-traefik.yaml`.** That template only renders
under `deployment.mode=multi` (`{{- if and .Values.traefik.enabled (eq .Values.deployment.type
"standalone") (eq .Values.deployment.mode "multi") }}`), which this repo does not use (see B3/
"deployment.mode: single" below) and carries the identical defect unpatched. If a future change
switches this chart to `mode: multi`, that template needs the same patch applied first.

**Regression coverage:** `tests/currentai_b1_single_traefik_routing_test.yaml` (new). Upstream's own
`tests/standalone_traefik_test.yaml` only exercises the multi-mode template, so there was zero
existing coverage for what we actually render. Verified the new test suite is a real check, not one
that can't go red: reverted the patch locally, confirmed all 5 assertions fail with the exact
"missing arg" diagnostics, then restored the patch and confirmed all 5 pass again.

## B2 — `SERVER_SECRET` is unstable under ArgoCD's render-only `helm template`

**File added:** `templates/externalsecret.currentai.yaml`.

`templates/_helpers.tpl`'s `pangolin.app.secretValue` helper resolves the app secret with a
`lookup "v1" "Secret" ...` call, falling back to `randAlphaNum` when the lookup finds nothing. ArgoCD
renders manifests with `helm template`, not `helm upgrade` — and `lookup` always returns nil under
`helm template` (it needs a live cluster connection `helm template` never opens), so the `else`
branch fires on *every* render, regardless of what's actually running.

Checked the actual blast radius rather than assuming a worst case: `templates/deployment-single.yaml`
has no `checksum/secret` (or `sha256sum`/`rollme`) annotation anywhere, so a Secret content change
does **not** roll the pod — `SERVER_SECRET` is read once as an env var at container start and stays
stable for the pod's lifetime. Live sessions are not dropped every reconcile. What actually happens
every reconcile: the rendered Secret's content differs from the live one, ArgoCD sees permanent
drift, and `selfHeal: true` keeps re-applying it — so the Application never reaches a stable Synced
state, and `helm template | diff` is useless as a review tool since every render differs. The real
bite is every **pod restart** (deploy, node drain, OOM kill, image pull) picking up whatever random
value the Secret happens to hold at that instant, invalidating every session cookie and resource
access token at an unpredictable moment — for a service whose resource tokens are the sole gate on
per-device endpoints, a silent auth-wide reset with no operator signal.

The fix doesn't work around the defect, it sidesteps it entirely: `templates/secrets.yaml` (the
generated-Secret template) is gated on `{{- if and (not .Values.pangolin.secret.existingSecretName)
.Values.pangolin.secret.generated.create }}` — setting `pangolin.secret.existingSecretName` (done in
`argo/environments/staging/pangolin-values.yaml`) skips that entire template, so the `randAlphaNum`
call is never reached at all; there is no random value anywhere in the render. The
`externalsecret.currentai.yaml` template added here creates a Secret of that same name, sourced from
AWS Secrets Manager via the `aws-secretsmanager` ClusterSecretStore (the same `dataFrom.extract`
whole-secret pattern `charts/agent-service/templates/externalsecret.yaml` already uses) — identical
content on every render and every pod restart.

Gated behind `currentai.serverSecretExternalSecret.enabled` (default `false`, so vendoring this
chart changes nothing for anyone using it with different values); fails fast at render time if
enabled without `pangolin.secret.existingSecretName` also set, so the two can't silently drift apart.

**Regression coverage:** the render-twice-diff test below. Confirmed: `helm template` run twice
against `argo/environments/staging/pangolin-values.yaml` is byte-identical, and zero `kind: Secret`
documents appear anywhere in the render.

```bash
helm template pangolin charts/pangolin -f ../../argo/environments/staging/pangolin-values.yaml > /tmp/a.yaml
helm template pangolin charts/pangolin -f ../../argo/environments/staging/pangolin-values.yaml > /tmp/b.yaml
diff /tmp/a.yaml /tmp/b.yaml && echo "stable"
grep -c '^kind: Secret$' /tmp/a.yaml   # must be 0
```

## B3 — resolved by `deployment.mode: single`, not by a further patch

Compose's local stack runs Traefik with `network_mode: service:gerbil` specifically so Traefik can
route into the WireGuard subnet toward a paired device — it needs to share gerbil's network
namespace. The equivalent on Kubernetes is **not** a patch: `deployment.mode: single` (as opposed to
the chart's default `multi`) already puts pangolin, gerbil, and traefik as three containers in *one*
Pod (`templates/deployment-single.yaml`), which share a network namespace natively, no
`network_mode` hack required. Confirmed by reading `deployment-single.yaml` directly: gerbil's own
args talk to Pangolin over `127.0.0.1`, and Traefik's B1 patch above does the same — that pattern
only works because they're in the same Pod.

Cost, stated plainly (not hidden by the fact that this "just works"): one Pod means a Traefik crash
restarts the whole Pod's container set only in the sense that kubelet restarts *that* container
independently (Kubernetes restarts containers individually within a Pod, not the whole Pod, on a
non-zero exit) — but PSA `enforce: privileged` (required for gerbil's `NET_ADMIN`) then applies to
every container in that Pod, not just gerbil. See "Risks" below.

## `pangolin.config.domains.*.cert_resolver` and `pangolin.config.traefik.cert_resolver`: required non-empty, deliberately inert

`_helpers.tpl`'s validation (PANGOLIN-059, PANGOLIN-014) requires both of these to be non-empty
whenever `traefik.enabled=true` — there's no way to configure "no ACME" by leaving them blank, even
though this design terminates TLS at the ALB and runs zero real ACME issuance. Both are set to the
literal string `"none"` in the staging values overlay: a deliberately inert placeholder, not a real
Traefik certificatesResolver name. Two things make this safe rather than merely quiet:

1. **Chart validation forces `traefik.config.letsencryptEmail` non-empty too** (PANGOLIN-014)
   whenever `traefik.enabled=true`, which means Traefik's own args *will* always configure a resolver
   literally named `letsencrypt` (`--certificatesresolvers.letsencrypt.acme.email=...`), regardless of
   whether anything references it. Naming our own fields `"none"` instead of `"letsencrypt"` means
   nothing in this config points at the one resolver that does exist — an unresolvable resolver name
   on a per-device router fails safe in Traefik (falls back to its own default TLS store) rather than
   triggering a real ACME attempt against a resolver that's actually configured and reachable.
2. **Confirmed empirically, not assumed:** whether a per-device router's TLS block references
   `cert_resolver` at all is decided by Pangolin's own server code, not this Helm chart —
   `getTraefikConfig.ts:1128` (the real `fosrl/pangolin` server, version 1.23.0 — the exact version
   pinned via `images.pangolin.tag` in the staging overlay) emits a bare `tls: {}` for every generated
   router, with no `certResolver` reference at all, confirmed during CUR-1266's local Compose
   bring-up against a live running instance. The Helm chart's config schema requiring a non-empty
   string doesn't mean Pangolin's runtime behavior uses it for anything on this version.

**Not independently re-verified against this specific chart+values combination with a live 1.23.0
instance** — only against the local Compose stack's own config shape. Re-run the local Phase 4
end-to-end test's redirect-loop / router-config checks (see the plan's "Verification" section)
against a real staging sync before trusting this for anything beyond a smoke test.

## `gerbil.startupMode: delayed` does nothing under `deployment.mode: single`

The chart's README documents `startupMode: delayed` as rendering Gerbil's resources but holding "the
**multi-mode** Gerbil Deployment" at `replicas: 0` until switched back to `normal` — read literally,
and confirmed by grepping the actual mechanism: the `if eq $startupMode "delayed" { $replicas = 0 }`
logic lives *only* in `templates/deployment-gerbil.yaml`, the `mode=multi` template. `templates/
deployment-single.yaml` — what `mode: single` actually renders — never references `startupMode` at
all. Setting it to `delayed` in our values overlay would be a complete, silent no-op: the whole
combined Pod still starts at `pangolin.replicaCount` immediately either way.

The staging values overlay leaves `gerbil.startupMode` at its default (`normal`) and documents the
consequence instead of chasing a nonexistent mitigation: a fresh Pangolin has no exit node until the
bootstrap runbook creates the org, so the gerbil *container* (not the whole Pod — Kubernetes restarts
containers individually, and pangolin/traefik keep running) will show a real `CrashLoopBackOff`
between first sync and bootstrap completion. This self-heals via Kubernetes' own restart backoff the
moment gerbil's `--remoteConfig` call starts succeeding — no flip-a-flag follow-up PR needed, unlike
what an earlier draft of this design assumed before the mechanism was actually read.

## Why `standalone`, not `controller`

The chart's `deployment.type: controller` mode is the upstream-tested path (installs a dedicated
`pangolin-kube-controller` that programs Traefik via real `IngressRoute`/`Middleware` CRDs) but
requires a cluster-wide Traefik installation with its own CRDs — this cluster standardizes on the AWS
Load Balancer Controller and has none of that, and installing a second, cluster-wide ingress
controller is out of scope for onboarding one service. `standalone` (this chart running its own
Traefik, patched per B1 above) keeps the footprint to one namespace.

## CloudNativePG comes bundled, not as a separate Application

An earlier draft of the staging rollout plan (written before this chart was actually fetched and
read) assumed CNPG's operator would need its own ArgoCD Application, referencing the upstream
`cloudnative-pg` chart remotely. That's not how this chart ships it: `Chart.yaml` already declares
`cloudnative-pg` (aliased `cnpg-operator`) and `cluster` (aliased `cnpg-cluster`) as dependencies,
vendored as `.tgz` subcharts right in `charts/pangolin/charts/`, each gated on its own
`<alias>.enabled` flag. Enabling both in the staging values overlay is the entire integration — one
Application, one sync, no multi-source ArgoCD version requirement.

**Before the first sync:** confirm no CNPG operator already exists cluster-wide
(`kubectl get crd clusters.postgresql.cnpg.io`) — the operator subchart installs cluster-scoped CRDs,
a `ClusterRole`, and a `MutatingWebhookConfiguration`/`ValidatingWebhookConfiguration`, which would
collide with an existing installation. If one exists, set `cnpg-operator.enabled: false` and keep
`cnpg-cluster.enabled: true` to create only our own `Cluster` CR against it.

**`ServerSideApply=true` is mandatory, not optional**, on the ArgoCD Application (already set in
`argo/apps/staging/pangolin.yaml`): the largest bundled CRD (`clusters.postgresql.cnpg.io`) renders
to ~253KB, which exceeds `kubectl`'s client-side `last-applied-configuration` annotation limit
(~262KB) once ArgoCD's own tracking metadata is added — confirmed by measuring the actual rendered
CRD document size, not assumed from the CNPG project's own general guidance.

`database.cloudnativepg.cluster.name` (defaults to `pangolin-db`) and `cnpg-cluster.fullnameOverride`
(also defaults to `pangolin-db`) already agree out of the box — chart validation
(`_helpers.tpl`, the `PANGOLIN-CNPG` fail) requires them to match, and neither needed overriding.

**`Prune=false`** is set via `cnpg-cluster.cluster.annotations` (`argocd.argoproj.io/sync-options:
Prune=false`) on the `Cluster` CR specifically — every Application here runs
`prune: true, selfHeal: true`, and pruning the `Cluster` CR cascades to delete its PVCs via CNPG's own
owner references, silently losing every paired device's row. The CNPG-managed PVCs themselves are
created by the operator directly at runtime, not by anything Helm renders, so ArgoCD never tracks or
prunes them independently — the `Cluster` CR is the one resource in this chain Argo can actually see.

## A real, independently-useful bug fix surfaced along the way

`charts/ingress/templates/ingress.yaml`'s `- host: {{ tpl .host $ }}` rendered a wildcard host
(`*.tunnel.stg.aipotluck.org`, needed for the per-device Ingress entry) unquoted — and an unquoted
leading `*` is YAML's alias indicator, not a literal character, so the rendered Ingress manifest
failed to parse (`helm lint`/`helm template` both errored: `did not find expected alphabetic or
numeric character`). This was a pre-existing defect in a shared chart, invisible until a wildcard host
was actually exercised — none of this repo's three existing services use one. Fixed with `| quote`;
verified both the new wildcard entry and the three existing single-host entries render correctly
afterward (existing entries render identically, just always-quoted now instead of situationally).

Same file also gained multi-path support (`paths:` list, each with its own `path`/`pathType`/
`targetService`) for the Pangolin dashboard host, which needs `/api/v1` routed to Pangolin's `external`
port (3000) and everything else routed to its `next` port (3002) — confirmed against
`templates/ingressroute-dashboard.yaml`'s own controller-mode routing split, the one place upstream
documents which port serves what. Backwards compatible: an entry with no `paths` key falls back to
the original single `targetService` → `path: /` behavior, unchanged.

## Known pre-existing chart-internal test failures (not ours, not fixed)

`helm unittest charts/pangolin` shows 5 failing assertions across `tests/database_test.yaml` and
`tests/default_test.yaml`, all the same root cause: those fixtures assert
`docker.io/fosrl/pangolin:1.18.2`, but `values.yaml`'s own default `images.pangolin.tag` is `1.18.3`
— an upstream test/values inconsistency in the tagged `0.1.0-alpha.1` release itself, unrelated to
anything in this directory. Moot for our deployment either way, since `images.pangolin.tag` is
overridden to `1.23.0` in the staging values overlay regardless of the chart's own default.

## Verification run against this vendored+patched copy

```bash
helm lint charts/pangolin -f argo/environments/staging/pangolin-values.yaml
helm unittest charts/pangolin        # 403 tests, 398 pass; 5 pre-existing failures above
helm template pangolin charts/pangolin -f argo/environments/staging/pangolin-values.yaml
```

All three pass/render clean as of this patch. No `kubectl`, no valid AWS credentials were available
in the environment this was written in — everything above is local (`helm lint`/`template`/
`unittest`) verification only. See the plan document's "Verification" section for the cluster-access
checklist this hands off to whoever applies it.
