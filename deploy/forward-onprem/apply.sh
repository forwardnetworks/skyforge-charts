#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-}"
if [[ -z "${KUBECONFIG}" ]]; then
  echo "KUBECONFIG is required" >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl --kubeconfig "$KUBECONFIG" apply -f "$DIR/pvc.yaml"
kubectl --kubeconfig "$KUBECONFIG" apply -f "$DIR/forward-skyforge.yaml"

