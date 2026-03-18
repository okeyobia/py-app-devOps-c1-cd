## FastAPI DevOps Playground Technical Guide

### Overview
- Lightweight FastAPI service used to demonstrate containerization, Helm/Argo CD delivery, and ingress automation workflows.
- Repository layout mixes application code (`app/`), deployment manifests (`k8s/`, `fastapi-chart/`), and supporting scripts (`scripts/`).
- Primary goals: showcase a minimal service, document the operational knobs, and provide copy-paste ready commands for local or cluster environments.

### Application Stack
- **Framework:** FastAPI with a custom lifespan hook logging startup/shutdown events.
- **Routing:** `app/routes.py` exposes root, health, and detail endpoints through a shared `APIRouter` that is mounted in `app/main.py`.
- **Configuration:** Pydantic `Settings` object pulls values from environment variables or a local `.env`, keeping defaults (`app_name`, `debug`).
- **Logging:** Standard logging configured at INFO level in `app/main.py` to surface lifecycle events.

### Configuration Model
| Variable | Default | Description |
| --- | --- | --- |
| `app_name` | My FastAPI Application | FastAPI `title`, visible in OpenAPI docs |
| `debug` | false | Enables FastAPI debug mode and richer error responses |
| `.env` | n/a | Optional file read via `Settings.Config.env_file` |

Configuration precedence is standard Pydantic Settings order: explicit keyword args > environment variables > `.env` file > class defaults.

### API Surface
| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/` | Smoke response showing the service is running |
| GET | `/health` | Liveness endpoint returning `{ "status": "healthy" }` |
| GET | `/api/v1/details` | Returns `date.today()` and container hostname for debugging |

All routes are async, making the handlers compatible with FastAPI's high concurrency model. Extend `app/routes.py` with additional endpoints and re-run `uvicorn` to pick edits up live.

### Local Development
1. Ensure Python 3.11+ plus Poetry (or your preferred tool) is installed.
2. Install dependencies: `poetry install` (or `pip install -r requirements.txt` once generated).
3. Run the app: `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`.
4. Open http://localhost:8000/docs to explore the automatically generated Swagger UI.

#### Optional ingress tunnel helper
- `scripts/dev_ingress.sh start` patches the Minikube ingress controller to LoadBalancer, launches `minikube tunnel`, waits for an external IP, and writes the resolved host (default `fastapi.local`) into `/etc/hosts`.
- `status` and `stop` subcommands inspect the tunnel, clean up `/etc/hosts`, and terminate the helper process.

### Containerization & Deployment
- **Docker:** The root `Dockerfile` packages the service for local or CI builds. Example: `docker build -t fastapi-devops .` then `docker run -p 8000:8000 fastapi-devops`.
- **Raw Kubernetes:** `k8s/` holds baseline `Deployment`, `Service`, and `Ingress` manifests. Apply directly with `kubectl apply -f k8s/` for lightweight demos.
- **Helm:** `fastapi-chart/` encapsulates the same manifests with templating, values overrides, and an Argo CD `Application` definition under `fastapi-chart/argo-cd/`. Use `helm install fastapi ./fastapi-chart -f fastapi-chart/values.yaml` or target Argo CD for GitOps syncs.

### Operations & Observability
- **Startup/Shutdown logs:** Lifespan context manager logs `Starting up...` and `Shutting down...`, useful in Kubernetes pod logs.
- **Health probes:** Map `/health` to Kubernetes liveness/readiness probes. Sample readiness block:
	```yaml
	readinessProbe:
		httpGet:
			path: /health
			port: http
		initialDelaySeconds: 5
		periodSeconds: 10
	```
- **Details endpoint:** `/api/v1/details` adds quick visibility into deployment time and pod hostname when debugging ingress or load balancer routing.

### Next Steps
- Add persistence or cache integrations in `app/config.py` (commented `database_url` placeholder exists).
- Extend Helm chart values for autoscaling, resource requests, and secret management.
- Wire Backstage catalog ingestion through `catalog-info.yaml` so the service stays discoverable within your internal developer portal.
