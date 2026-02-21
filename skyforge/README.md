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
- Dedicated worker deployment is always enabled as a singleton (`replicas: 1`) and processes queued runs from PubSub.
- `skyforge.cloudflareTunnel`: Optional `cloudflared` tunnel to expose Skyforge externally (see `components/charts/skyforge/docs/cloudflare-tunnel.md`).
- `skyforge.dex.authMode`: Dex auth profile (`google`, `local`, `ldap`, `oidc`).
- `skyforge.redoc.enabled`: Enable the ReDoc API docs UI.
- `skyforge.openApiUrl`: Optional override for the OpenAPI spec URL consumed by ReDoc.
- `skyforge.encoreRuntimeConfig`: Optional Encore runtime infrastructure config (`ENCORE_RUNTIME_CONFIG`).
- `skyforge.encoreCfg`: Optional typed Encore config for the `skyforge` service (`ENCORE_CFG_SKYFORGE`).
- `images.*`: Override container images.
- `images.skyforgeServerWorker`: Dedicated task worker image (built with `encore build docker --services=...` including the `worker` service).
- `secrets.items`: Provide secret values.
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  NetBox and Nautobot.
- `secrets.items.db-forward-app-password` / `secrets.items.db-forward-fdb-password`: Forward app/FDB
  Postgres passwords used to provision shared DB roles and sync `forward` namespace credentials.
- `secrets.create`: Set to `false` if you manage secrets out-of-band.

Object storage note: Skyforge deploys `s3gw` for in-cluster S3. Some Gitea config keys still use `MINIO_*` naming because that is Gitea's S3 driver interface; they point at `s3gw`, not a MinIO deployment.

See `components/charts/skyforge/values.yaml` for the full list of defaults.

Typed Encore config (`config.Load`) can be injected via `skyforge.encoreCfg.*`; the chart encodes the JSON as base64url without padding (Encore expects `base64.RawURLEncoding`) and sets `ENCORE_CFG_SKYFORGE`.

Note: the chart always forces `"TaskWorkerEnabled": true` in the worker’s `ENCORE_CFG_WORKER` payload.

## Cron

Skyforge uses Encore cron jobs for periodic maintenance (queued-task reconcile, etc), so the Helm
chart does not install Kubernetes CronJobs for these tasks.

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
