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
- `skyforge.labppApiUrl`: Optional LabPP API base URL (defaults to `<eve web>/labpp`).
- `skyforge.labppSkipTlsVerify`: `true` to skip LabPP TLS verification.
- `skyforge.labppProxy`: Optional Traefik proxy for exposing LabPP API endpoints via `https://<skyforge-hostname>/labpp/<name>/...`.
- `skyforge.eveProxy`: Optional Traefik proxy for exposing EVE-NG UI via `https://<skyforge-hostname>/labs/<name>/...` (used for SSO).
- `skyforge.pkiDefaultDays`: Default certificate TTL (days) for the PKI UI.
- `images.*`: Override container images.
- `secrets.items`: Provide secret values (use `--set-file` for PEM/SSH keys).
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  NetBox, Nautobot, and the code-server sync job.
- `secrets.items.skyforge-pki-ca-cert` / `secrets.items.skyforge-pki-ca-key`: Optional CA cert/key for PKI issuance.
- `secrets.create`: Set to `false` if you manage secrets out-of-band (for example, using the
  k3s `k8s/overlays/k3s-traefik-secrets` overlay).

See `charts/skyforge/values.yaml` for the full list of defaults.

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
