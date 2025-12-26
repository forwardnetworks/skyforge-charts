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
- `images.*`: Override container images.
- `secrets.items`: Provide secret values (use `--set-file` for PEM/SSH keys).

See `charts/skyforge/values.yaml` for the full list of defaults.
