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
- `images.*`: Override container images.
- `secrets.items`: Provide secret values (use `--set-file` for PEM/SSH keys).
- `secrets.items.skyforge-admin-shared.password`: Shared admin password used to seed Skyforge, Gitea,
  Semaphore, NetBox, Nautobot, and the code-server sync job.

See `charts/skyforge/values.yaml` for the full list of defaults.
