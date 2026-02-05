# Contributing to Skyforge Charts

Thanks for contributing.

This repository contains the Helm chart for Skyforge OSS. For the meta repo (submodules, bootstrap, and cross-component docs), see `forwardnetworks/skyforge`.

## Code of Conduct
By participating, you agree to the Code of Conduct in `CODE_OF_CONDUCT.md`.

## Development
- Lint chart: `helm lint skyforge`
- Render chart (without secrets): `helm template skyforge ./skyforge -n skyforge --set secrets.create=false`

## Secrets
Do not commit secrets (`*-secrets.yaml`, credentials, kubeconfigs).

## PRs
- Keep PRs small and scoped.
- Update docs when behavior changes.
