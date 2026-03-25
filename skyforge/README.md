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

Production profile for `skyforge.local.forwardnetworks.com`:

```bash
helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --create-namespace \
  -f values.yaml \
  -f values-prod-skyforge-local.yaml \
  -f /path/to/skyforge-secrets.yaml \
  --wait --timeout 15m
```

## Configuration

- `skyforge.hostname`: Public hostname for ingress routes.
- `skyforge.domain`: Email/domain suffix used by default users.
- `skyforge.gateway.addresses`: Optional explicit Cilium Gateway address list (recommended for node-IP ingress to avoid `AddressNotAssigned` status).
- `skyforge.forwardCluster.hostname`: Optional dedicated Forward UI hostname (for example `skyforge-fwd.local.forwardnetworks.com`).
- `skyforge.forwardCluster.tlsSecretName`: TLS Secret used for the dedicated Forward hostname listener when `forwardCluster.hostname` differs from `skyforge.hostname` (default `proxy-tls-fwd`).
- `skyforge.forwardCluster.nodeRoleReconciler.*`: Optional in-cluster reconciler that continuously enforces the desired Forward node-role labels (`fwd-master`, `fwd-monitoring`, `fwd-compute-worker`, `fwd-search-worker`, plus `forwardnetworks.com/role` and scratch-group labels) from chart values so node re-registration does not strand Forward master pods.
- `skyforge.publicTunnel.ngrok.*`: Optional ngrok relay deployment that tunnels to the in-cluster Cilium Gateway Service (`cilium-gateway-skyforge` by default). Keep auth token in a Kubernetes Secret; do not set it in values files.
- `skyforge.kne.*`: Optional KNE install from vendored manifests (tracked from `forwardnetworks/kne`).
- `skyforge.kne.controllers.*`: Installs KNE vendor controller stacks (ceoslab/cdnos/srlinux/lemming) required for CRD-backed device provisioning.
- Dedicated worker deployment is always enabled as a singleton (`replicas: 1`) and processes queued runs from PubSub.
- `skyforge.auth.mode`: Skyforge browser auth mode (`local` or `oidc`).
- `skyforge.dex.authMode`: Dex connector profile (`google`, `local`, `oidc`).
- `skyforge.redoc.enabled`: Enable the ReDoc API docs UI.
- `skyforge.openApiUrl`: Optional override for the OpenAPI spec URL consumed by ReDoc.
- `skyforge.encoreRuntimeConfig`: Optional Encore runtime infrastructure config (`ENCORE_RUNTIME_CONFIG`).
- `skyforge.encoreCfg`: Optional typed Encore config for the `skyforge` service (`ENCORE_CFG_SKYFORGE`).
- `images.*`: Override container images.
- `images.skyforgeServerWorker`: Dedicated task worker image (built by `./scripts/build-push-skyforge-server.sh --tag <tag>`, which always publishes `<tag>-worker`).
- `secrets.items`: Provide secret values.
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  NetBox and Nautobot.
- `secrets.items.dex-client-gitea-secret.dex-client-gitea-secret`: Dex OIDC client secret for Gitea (required when `skyforge.gitea.enabled=true`).
- `secrets.items.dex-client-yaade-secret.dex-client-yaade-secret`: Dex OIDC client secret for Yaade/API Testing (required when `skyforge.yaade.enabled=true`; autogen when `secrets.create=true`).
- `secrets.items.dex-client-netbox-secret.dex-client-netbox-secret`: Dex OIDC client secret for NetBox (required when `skyforge.netbox.enabled=true`).
- `secrets.items.dex-client-nautobot-secret.dex-client-nautobot-secret`: Dex OIDC client secret for Nautobot (required when `skyforge.nautobot.enabled=true`).
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

- `gitea-admin-bootstrap`
- `netbox-admin-bootstrap`
- `nautobot-admin-bootstrap`

These jobs create (or update) the local admin user and sync its password from the
`skyforge-admin-shared` secret.

To re-run the sync (for example, after rotating the shared password), delete the completed jobs
and run a Helm upgrade:

```bash
kubectl -n skyforge delete job \
  gitea-admin-bootstrap \
  netbox-admin-bootstrap \
  nautobot-admin-bootstrap

helm upgrade --install skyforge oci://ghcr.io/forwardnetworks/charts/skyforge \
  -n skyforge --reuse-values
```
