# Skyforge Helm Chart

This chart renders the Skyforge stack using the Kubernetes manifests in the repo,
with value-based substitution for hostnames, image references, and config defaults.

## Install

```bash
helm upgrade --install skyforge ./charts/skyforge -n skyforge --create-namespace \
  -f values.yaml
```

## Configuration

- `skyforge.hostname`: Public hostname for ingress routes.
- `skyforge.domain`: Email/domain suffix used by default accounts.
- `skyforge.labppApiUrl`: Optional LabPP API base URL (defaults to `<eve web>/labpp`).
- `skyforge.labppSkipTlsVerify`: `true` to skip LabPP TLS verification.
- `skyforge.labppProxy`: Optional Traefik proxy for exposing LabPP API endpoints via `https://<skyforge-hostname>/labpp/<name>/...`.
- `images.*`: Override container images.
- `secrets.items`: Provide secret values (use `--set-file` for PEM/SSH keys).
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  Semaphore, NetBox, Nautobot, and the code-server sync job.
- `secrets.create`: Set to `false` if you manage secrets out-of-band (for example, using the
  k3s `k8s/overlays/k3s-traefik-secrets` overlay).

See `charts/skyforge/values.yaml` for the full list of defaults.

## Admin bootstrap and password sync

The chart includes one-time admin bootstrap jobs:

- `gitea-admin-bootstrap`
- `semaphore-admin-bootstrap`
- `netbox-admin-bootstrap`
- `nautobot-admin-bootstrap`

These jobs create (or update) the local admin account and sync its password from the
`skyforge-admin-shared` secret.

To re-run the sync (for example, after rotating the shared password), delete the completed jobs
and run a Helm upgrade:

```bash
kubectl -n skyforge delete job \
  gitea-admin-bootstrap \
  semaphore-admin-bootstrap \
  netbox-admin-bootstrap \
  nautobot-admin-bootstrap

helm upgrade --install skyforge ./charts/skyforge -n skyforge --reuse-values
```
