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
helm upgrade --install skyforge ./charts/skyforge -n skyforge --create-namespace \
  -f values.yaml
```

## Configuration

- `skyforge.hostname`: Public hostname for ingress routes.
- `skyforge.domain`: Email/domain suffix used by default accounts.
- `skyforge.workerReplicaCount`: Dedicated task worker replica count (processes queued runs from PubSub).
- `skyforge.labpp.runnerImage`: LabPP runner image (job executed by skyforge-server).
- `skyforge.labpp.runnerPullPolicy`: Image pull policy for the LabPP runner.
- `skyforge.labpp.runnerPvc`: PVC name mounted at `/var/lib/skyforge` for templates/configs (default `skyforge-server-data`).
- `skyforge.labpp.configDirBase`: LabPP config output dir (default `/var/lib/skyforge/labpp/configs`).
- `skyforge.labpp.configVersion`: LabPP properties file version (default `1.0`).
- `skyforge.labpp.netboxUrl`: NetBox base URL for LabPP allocations.
- `skyforge.labpp.netboxMgmtSubnet`: NetBox management subnet CIDR for LabPP allocations.
- `skyforge.labpp.s3Region`: Optional LabPP S3 region.
- `skyforge.labpp.s3Bucket`: Optional LabPP S3 bucket.
- `skyforge.cloudflareTunnel`: Optional `cloudflared` tunnel to expose Skyforge externally (see `charts/skyforge/docs/cloudflare-tunnel.md`).
- `skyforge.labppProxy`: Optional Traefik proxy for exposing LabPP API endpoints via `https://<skyforge-hostname>/labpp/<name>/...`.
- `skyforge.eveProxy`: Optional Traefik proxy for exposing EVE-NG UI via `https://<skyforge-hostname>/labs/<name>/...` (used for SSO).
- `skyforge.pkiDefaultDays`: Default certificate TTL (days) for the PKI UI.
- `skyforge.sshDefaultDays`: Default SSH certificate TTL (days) for the PKI UI.
- `skyforge.encoreRuntimeConfig`: Optional Encore runtime infrastructure config (`ENCORE_RUNTIME_CONFIG`).
- `skyforge.encoreCfg`: Optional typed Encore config for the `skyforge` service (`ENCORE_CFG_SKYFORGE`).
- `images.*`: Override container images.
- `images.skyforgeServerWorker`: Dedicated task worker image (built with `-tags=skyforge_worker`).
- `secrets.items`: Provide secret values (use `--set-file` for PEM/SSH keys).
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  NetBox and Nautobot.
- `secrets.items.skyforge-pki-ca-cert` / `secrets.items.skyforge-pki-ca-key`: Optional CA cert/key for PKI issuance.
- `secrets.items.skyforge-ssh-ca-key`: Optional SSH CA key for SSH user certificates.
- `secrets.create`: Set to `false` if you manage secrets out-of-band (for example, using the
  k3s `k8s/overlays/k3s-traefik-secrets` overlay).

See `charts/skyforge/values.yaml` for the full list of defaults.

Typed Encore config (`config.Load`) can be injected via `skyforge.encoreCfg.*`; the chart base64url-encodes the JSON and sets `ENCORE_CFG_SKYFORGE`.

Note: the chart no longer sets `SKYFORGE_TASK_WORKER_ENABLED` by default. Prefer enabling the worker by setting `"TaskWorkerEnabled": true` in `skyforge.encoreCfg.workerJson` and running a dedicated worker deployment (`skyforge.workerReplicaCount > 0`).

## Cron

Skyforge uses Encore cron jobs for periodic maintenance (queued-task reconcile, etc), so the Helm
chart does not install Kubernetes CronJobs for these tasks.

## Admin bootstrap and password sync

The chart includes one-time admin bootstrap jobs:

- `gitea-admin-bootstrap`
- `netbox-admin-bootstrap`
- `nautobot-admin-bootstrap`

These jobs create (or update) the local admin account and sync its password from the
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
