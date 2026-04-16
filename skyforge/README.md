# Skyforge Helm Chart

This chart renders the Skyforge stack using the Kubernetes manifests in the repo,
with value-based substitution for hostnames, image references, and config defaults.

## Install

Preferred: publish the chart to GHCR and install from the OCI registry (no chart files on the host).

```bash
gh auth token | helm registry login ghcr.io -u "$(gh api user -q .login)" --password-stdin

helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  -f deploy/skyforge-values.yaml \
  -f deploy/skyforge-secrets.yaml
```

For local development only, you can still install from the chart directory:

```bash
helm upgrade --install skyforge ./components/charts/skyforge -n skyforge --create-namespace \
  -f values.yaml
```

Production profile for the internal Skyforge hostname `skyforge.local.forwardnetworks.com`:

```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  -f values.yaml \
  -f values-prod-skyforge-local.yaml \
  -f /path/to/skyforge-secrets.yaml \
  --wait --timeout 15m
```

## Configuration

- `skyforge.hostname`: Primary internal hostname for ingress routes.
- `skyforge.domain`: Email/domain suffix used by default users.
- `skyforge.gateway.addresses`: Optional explicit Cilium Gateway address list. Leave this empty when Cilium runs Gateway API in host-network mode; use it only with LB-IPAM + L2 announcement pools.
- `skyforge.forward.baseUrl`: Optional managed Forward API base URL for Skyforge quick-deploy/sync workflows. In clusters where backend pods do not resolve or should not hairpin through the public Forward VIP, set this explicitly to the in-cluster service URL such as `https://fwd-appserver.forward.svc:8443`.
- `skyforge.gitea.apiUrl`: Server-side Gitea API base URL. For in-cluster jobs and workers, prefer the service URL such as `http://gitea.skyforge.svc.cluster.local:3000/api/v1`. Skyforge also derives raw and Git LFS object downloads from this base for demo seed ingestion, so using the internal service avoids public-VIP hairpin timeouts from worker pods.
- `skyforge.gitea.url`: Browser-facing Gitea base URL. Keeping this at `/git` preserves same-origin browser links while allowing `skyforge.gitea.apiUrl` to stay internal-only.
- `skyforge.forwardCluster.hostname`: Optional dedicated Forward UI hostname (for example `skyforge-fwd.local.forwardnetworks.com`).
- `skyforge.forwardCluster.tlsSecretName`: TLS Secret used for the dedicated Forward hostname listener when `forwardCluster.hostname` differs from `skyforge.hostname` (default `proxy-tls-fwd`).
- `skyforge.forwardImages.tag`: Shared Harbor release tag for Skyforge-owned Forward images. Set this to the same value as the upstream Forward `app.image_version` so the collector and optional Skyforge-owned compute/search workers do not drift from the main Forward release.
- `skyforge.forwardCluster.nodeRoleReconciler.*`: Optional in-cluster reconciler that continuously enforces the desired Forward node-role labels (`fwd-master`, `fwd-monitoring`, `fwd-compute-worker`, `fwd-search-worker`, plus `forwardnetworks.com/role` and scratch-group labels) from chart values so node re-registration does not strand Forward master pods. In production, keep more than one worker in the `master` set so `fwd-appserver` and `fwd-backend-master` can reattach their RWO scratch PVCs onto a healthy node after a reboot.
- `skyforge.forwardCluster.workers.*`: Optional Skyforge-owned compute/search worker manifest set for the current on-prem/shared-cluster Forward deployment contract. This path renders the worker headless Services, fluent-bit ConfigMaps, and Deployments directly in the Forward namespace using Harbor image refs, explicit CPU/memory resources, and optional per-worker runtime flags such as `JAVA_TOOL_OPTIONS`. It stays disabled until `skyforge.forwardCluster.workers.owner=skyforge`.
- `skyforge.forwardCluster.workers.owner`: Worker manifest owner. Use `upstream` to keep the upstream Forward Helm chart in control, or `skyforge` to move ownership into this chart.
- `skyforge.forwardCluster.workers.adoptionAcknowledged=true`: Required when `owner=skyforge`. This is an explicit ownership transfer guard: the upstream Forward release must stop managing `fwd-compute-worker` and `fwd-search-worker` before rollout claims them here.
- `skyforge.forwardCluster.upstreamWorkerRuntime.*`: Post-Helm runtime patches for upstream-owned Forward compute/search workers. Use these to enforce the upstream worker `MEMORY_PROFILE`, explicit JVM heap caps, optional `JAVA_TOOL_OPTIONS`, and pod memory request/limit values when the upstream Forward chart does not expose first-class knobs for those pods. For large-snapshot local runs, prefer `ISOLATED_WORKER` plus explicit memory caps over `SHARED_CLUSTER`; otherwise the hardcoded shared-cluster reservation can shrink worker heap down to roughly 1 GiB.
- `skyforge.forwardCluster.workers.rollout.*`: Worker rollout safety settings (rolling update shape, readiness window, and termination drain sleep) used to avoid worker-store endpoint gaps during pod replacement.
- `skyforge.forwardCluster.workers.pdb.*`: Worker PodDisruptionBudget settings to prevent voluntary disruption from dropping all compute/search worker endpoints.
- `skyforge.forwardCluster.workers.discovery.nodeAgentHeadlessAlias.*`: Optional alias Service (`fwd-node-agent-headless` by default) mapped to search workers for backend worker-discovery compatibility, rendered whenever `skyforge.forwardCluster.enabled=true` so discovery remains stable across worker ownership modes.
- `values-prod-skyforge-local-forward-workers-skyforge.yaml`: Explicit takeover overlay for the Skyforge-owned worker path. This file is intentionally separate from the main production profile because the upstream Forward release still needs its own rollout-path change to stop rendering the worker objects first.
- Forward compute/search scale is bounded by the number of nodes labeled for each worker role because both the upstream and Skyforge-owned worker manifests use required pod anti-affinity against the same worker app name. If you want five compute workers and five search workers, label five eligible nodes for each role and set the worker replica count to `5` in the owning config surface.

### Forward worker ownership handoff

The handoff is two-step on purpose:

1. Stop the upstream Forward release from rendering `fwd-compute-worker` and
   `fwd-search-worker`.
2. Add `values-prod-skyforge-local-forward-workers-skyforge.yaml` to the
   Skyforge chart rollout so this chart takes ownership of those names.

Do not flip the main production profile directly. The upstream Forward chart has
no worker-disable hook today, so a same-name ownership transfer must be staged
deliberately at the rollout boundary rather than hidden in defaults.

For the local/prod Forward bootstrap script, the matching rollout-path toggle is:

```bash
SKYFORGE_FORWARD_WORKER_MANIFEST_OWNER=skyforge
```

That script now stages a temporary copy of the upstream Forward chart with the
compute/search worker templates removed before Helm runs. Keep the default as
`upstream` until the Skyforge takeover overlay is part of the same rollout.
- `skyforge.burst.hetzner.*`: Optional Hetzner burst-capacity contract. This is disabled by default. The supported gateway baseline is Hetzner's built-in WireGuard app (`image=wireguard`) on `cx23`, with Skyforge initiating outbound to that gateway and local route reconciliation carrying the burst CIDRs. Use `skyforge.burst.hetzner.provisioningEnabled=false` to keep the scaffold configured but disarmed.
- `skyforge.burst.hetzner.wireguard.hub.*`: Optional host-network deployment that owns the local WireGuard interface on one selected node. In the supported model, this node initiates outbound to a dedicated Hetzner gateway listener using peer config fragments stored out of band.
- `skyforge.burst.hetzner.routeReconciler.*`: Optional privileged host-network DaemonSet that continuously enforces return routes on selected worker nodes for Hetzner burst CIDRs carried behind a local WireGuard gateway.
- `skyforge.kne.*`: Optional KNE install from vendored manifests (tracked from `forwardnetworks/kne`). On Cilium clusters, KNE meshnet requires `kube-system/cilium-config` `cni-exclusive=false`; otherwise Cilium renames `00-meshnet.conflist` out of the active chain and multi-node links stall at `Connected 1 interfaces out of 2`. Rollout guardrails must also run after the `meshnet` DaemonSet is ready so active `00-meshnet.conflist` is restored if needed and `multus.kubeconfig` points at a reachable control-plane endpoint.
- `skyforge.kne.controllers.*`: Installs the KNE vendor controller stack used by this workflow (`ceoslab` only). Cisco (`iol`, `ios-xrd`) and kubevirt paths use native KNE runtime support and do not require additional vendor controllers.
- Dedicated worker deployment is always enabled as a singleton (`replicas: 1`) and processes queued runs from PubSub.
- `skyforge.auth.mode`: Skyforge browser auth mode (`local` or `oidc`).
- `skyforge.dex.authMode`: Dex connector profile (`google`, `local`, `oidc`).
- `skyforge.redoc.enabled`: Enable the ReDoc API docs UI.
- `skyforge.openApiUrl`: Optional override for the OpenAPI spec URL consumed by ReDoc.
- `skyforge.encoreRuntimeConfig`: Optional Encore runtime infrastructure config (`ENCORE_RUNTIME_CONFIG`).
- `skyforge.encoreCfg`: Optional typed Encore config for the `skyforge` service (`ENCORE_CFG_SKYFORGE`).
- `skyforge.audit.retention`: Audit retention duration. Set to `0` to disable automatic audit cleanup. Default `180d`.
- `images.*`: Override container images.
- `images.skyforgeServerWorker`: Dedicated task worker image (built by `./scripts/build-push-skyforge-server.sh --tag <tag>`, which always publishes `<tag>-worker`).
- `secrets.items`: Provide secret values.
- `secrets.items.skyforge-audit-export-signing-key.skyforge-audit-export-signing-key`: PEM-encoded
  Ed25519 PKCS#8 private key used to sign audit exports. Audit exports fail closed when this secret is not configured.
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  NetBox and Nautobot.
- `skyforge.gitea.oidc.*`: Controls Gitea's native Dex-backed onboarding behavior (auto-registration,
  account linking, username claim selection) so first-time SSO users do not need to manually register/link.
- `skyforge.coder.oidcUsernameField`: Coder OIDC username claim (default: `preferred_username`).
- `skyforge.coder.oidcAllowSignups`: Keeps first-time Dex-authenticated users on the normal Coder sign-in path once the owner exists (default: `true`).
- `skyforge.coder.bootstrap.*`: First-owner bootstrap for Coder. By default the chart creates a `skyforge` owner using the shared admin password so users do not hit Coder's first-user setup screen.
- `skyforge.jira.database.*`: Managed Jira database contract. When `skyforge.jira.managed=true`, the chart can provision a dedicated Postgres database/user and generate Jira's `dbconfig.xml` on startup so users skip the Atlassian database setup wizard.
- `secrets.items.db-jira-password.db-jira-password`: Jira Postgres password (autogen when `secrets.create=true`).
- `secrets.items.dex-client-gitea-secret.dex-client-gitea-secret`: Dex OIDC client secret for Gitea (required when `skyforge.gitea.enabled=true`).
- `secrets.items.dex-client-yaade-secret.dex-client-yaade-secret`: Dex OIDC client secret for Yaade/API Testing (required when `skyforge.yaade.enabled=true`; autogen when `secrets.create=true`).
- `secrets.items.dex-client-netbox-secret.dex-client-netbox-secret`: Dex OIDC client secret for NetBox (required when `skyforge.netbox.enabled=true`).
- `secrets.items.dex-client-nautobot-secret.dex-client-nautobot-secret`: Dex OIDC client secret for Nautobot (required when `skyforge.nautobot.enabled=true`).
- `secrets.items.dex-client-grafana-secret.dex-client-grafana-secret`: Dex OIDC client secret for Grafana when observability Grafana OIDC is enabled.
- `skyforge.observability.grafana.oidc.tokenURL` / `apiURL`: Optional override for Grafana's server-side Dex exchange endpoints; defaults keep token and userinfo on in-cluster Dex.
- `secrets.items.db-forward-app-password` / `secrets.items.db-forward-fdb-password`: Forward app/FDB
  Postgres passwords used to provision shared DB roles and sync `forward` namespace credentials.
- `secrets.create`: Set to `false` if you manage secrets out-of-band.

Object storage note: Skyforge deploys `s3gw` for in-cluster S3. Some Gitea config keys still use provider-specific legacy key names in Gitea itself; they point at `s3gw` storage.

See `components/charts/skyforge/values.yaml` for the full list of defaults.

Typed Encore config (`config.Load`) can be injected via `skyforge.encoreCfg.*`; the chart encodes the JSON as base64url without padding (Encore expects `base64.RawURLEncoding`) and sets `ENCORE_CFG_SKYFORGE`.

Note: the chart always forces `"TaskWorkerEnabled": true` in the worker’s `ENCORE_CFG_WORKER` payload.

## Cron

Skyforge uses Encore cron jobs for periodic maintenance:

- worker heartbeat
- queued/running task reconciliation
- user sync
- cloud credential checks
- queue/capacity/governance periodic maintenance

The chart no longer installs Kubernetes CronJobs for these flows.

## Admin bootstrap and password sync

The chart includes one-time admin bootstrap jobs:

- `coder-admin-bootstrap`
- `gitea-admin-bootstrap`
- `netbox-admin-bootstrap`
- `nautobot-admin-bootstrap`

These jobs create (or update) the local admin user and sync its password from the
`skyforge-admin-shared` secret.

To re-run the sync (for example, after rotating the shared password), delete the completed jobs
and run a Helm upgrade:

```bash
kubectl -n skyforge delete job \
  coder-admin-bootstrap \
  gitea-admin-bootstrap \
  netbox-admin-bootstrap \
  nautobot-admin-bootstrap

helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --reuse-values
```
