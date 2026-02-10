# Forward On-Prem (In-Cluster) On Skyforge

This directory makes the current Forward "on-prem app cluster" deployment repeatable
inside the Skyforge Kubernetes cluster.

## Assumptions

- Skyforge is installed in namespace `skyforge`.
- Skyforge Postgres service is `db.skyforge.svc.cluster.local:5432` (Postgres 15+).
- Forward is deployed in namespace `forward`.
- StorageClass `longhorn` exists.
- Forward images are already present on the node(s) running Forward Pods
  (for example imported into k3s/containerd), or the image registry in the manifest
  is reachable from those nodes.

## 1) Ensure Postgres Has Enough Connections

Forward opens a lot of DB connections. Skyforge's bundled Postgres defaults to
`max_connections=100`, which is too low.

The Skyforge chart in this repo pins Postgres to `max_connections=300`.
If you already have Skyforge deployed, you can patch live:

```bash
KUBECONFIG=... kubectl -n skyforge patch deploy db --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args","value":["-c","max_connections=300"]}]'
```

## 2) Create Forward PVCs

```bash
KUBECONFIG=... kubectl apply -f pvc.yaml
```

## 3) Bootstrap DB Roles + Credentials

This creates:

- Secrets in `forward` namespace:
  - `postgres.fwd-pg-app.credentials` (user `fwd_app`)
  - `postgres.fwd-pg-fdb.credentials` (user `fwd_fdb`)
- Postgres roles and databases (owned by those roles):
  - `forward`
  - `fwd_fdb`

```bash
KUBECONFIG=... ./bootstrap-db.sh
```

## 4) Deploy Forward Workloads

```bash
KUBECONFIG=... kubectl apply -f forward-skyforge.yaml
```

Notes:

- `fwd-autopilot` is scaled to `0` by default (it tends to re-scale StatefulSets and is noisy).
- Pods are pinned via `nodeSelector: forwardnetworks.com/role=forward`. Label at least one node:

```bash
KUBECONFIG=... kubectl label node skyforge-2 forwardnetworks.com/role=forward --overwrite
```

## 5) Expose Forward Under `/fwd` (Skyforge SSO)

Enable Skyforge's `/fwd` proxy (chart already supports this):

```bash
helm -n skyforge upgrade skyforge ../../skyforge \
  --reuse-values \
  --set skyforge.forwardApp.enabled=true \
  --set skyforge.forwardApp.pathPrefix=/fwd \
  --set skyforge.forwardApp.upstreamNamespace=forward \
  --set skyforge.forwardApp.upstreamService=fwd-appserver \
  --set skyforge.forwardApp.upstreamPort=8080 \
  --set skyforge.forwardApp.requireAuth=true
```

