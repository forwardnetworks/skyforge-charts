# Cloudflare Tunnel (cloudflared)

This chart can optionally run `cloudflared` inside the cluster to expose Skyforge externally **without opening inbound ports** on the k3s host.

Skyforge already routes HTTP via Traefik; the tunnel should forward traffic to Traefik so all existing host/path routing continues to work.

## Prereqs

- A Cloudflare account + a zone where you want to publish Skyforge (e.g. `skyforge.example.com`)
- A Cloudflare Tunnel created for Skyforge
- A Kubernetes Secret containing either:
  - a tunnel **token** (simplest), or
  - a `credentials.json` file + tunnel UUID

## Option A (recommended): token mode

1) In the Cloudflare dashboard: Zero Trust → Networks → Tunnels → Create tunnel, then copy the connector token.

2) Create the Secret in the Skyforge namespace:

```bash
kubectl -n skyforge create secret generic cloudflared-skyforge-token \
  --from-literal=token='<PASTE_TOKEN_HERE>'
```

3) Enable the tunnel in `skyforge-values.yaml`:

```yaml
skyforge:
  cloudflareTunnel:
    enabled: true
    tokenSecretName: cloudflared-skyforge-token
    # Hostname defaults to skyforge.hostname; set if different:
    # hostname: "skyforge.example.com"
```

4) Configure the **Public Hostname** mapping in Cloudflare to point the tunnel to your origin:
- If you use Cloudflare’s Public Hostname UI, you can route the hostname directly to the tunnel (recommended).

## Option B: credentials.json mode (explicit ingress rules in Kubernetes)

1) Create the tunnel and download `credentials.json` (or copy it from your `~/.cloudflared/<TUNNEL_ID>.json`).

2) Create the Secret in the Skyforge namespace:

```bash
kubectl -n skyforge create secret generic cloudflared-skyforge-creds \
  --from-file=credentials.json=/path/to/credentials.json
```

3) Enable the tunnel in values:

```yaml
skyforge:
  cloudflareTunnel:
    enabled: true
    tunnelId: "<TUNNEL_UUID>"
    credentialsSecretName: cloudflared-skyforge-creds
    hostname: "skyforge.example.com"
    # Optional:
    # additionalHostnames:
    #   - "tool.skyforge.example.com"
```

## Notes

- The default `service` target is Traefik: `http://traefik.kube-system.svc.cluster.local:80`.
- Do not commit Cloudflare tokens or credentials files into git; always use Kubernetes Secrets.
