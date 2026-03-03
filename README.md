## FastAPI DevOps Playground

This repo contains a small FastAPI service packaged for container/Kubernetes demos.

### Automating ingress tunnel + hosts entry

Use `scripts/dev_ingress.sh` to keep `fastapi.local` mapped to the minikube ingress controller and to run `minikube tunnel` in the background.

```bash
chmod +x scripts/dev_ingress.sh   # one-time permission update

# Start the tunnel, patch the ingress controller Service to LoadBalancer,
# wait for an external IP, and update /etc/hosts accordingly.
scripts/dev_ingress.sh start

# Check current status (Service type, LoadBalancer IP, hosts entry, tunnel PID).
scripts/dev_ingress.sh status

# Remove the hosts entry and stop the tunnel background process.
scripts/dev_ingress.sh stop
```

Environment variables:

- `FASTAPI_HOST` (default `fastapi.local`) overrides the hostname written to `/etc/hosts`.
- `INGRESS_NAMESPACE` and `INGRESS_SERVICE` (default `ingress-nginx` / `ingress-nginx-controller`) target a different ingress controller.

Inspect `.devinfra/minikube-tunnel.log` if the script reports issues getting a LoadBalancer IP.
