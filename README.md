# FleetDM Kubernetes Deployment

Helm chart for deploying FleetDM with MySQL and Redis on Kubernetes.

## Prerequisites

- Docker
- kubectl
- Helm 3
- Kind or Minikube

## Quick Start

```bash
make cluster    # Create local cluster
make install    # Deploy FleetDM
make verify     # Check status
```

Access UI:
```bash
make port-forward
# Visit http://localhost:8080
```

## Installation

### 1. Create Cluster

Using Kind (default):
```bash
make cluster
```

Using Minikube:
```bash
make cluster CLUSTER_TYPE=minikube
```

### 2. Deploy FleetDM

```bash
make install
```

This automatically:
- Deploys FleetDM (2 replicas), MySQL, and Redis
- Initializes database with `fleet prepare db`
- Configures persistent storage

### 3. Verification Steps

**Check pods are running:**
```bash
kubectl get pods -n fleetdm
```

Expected output:
```
NAME                       READY   STATUS    RESTARTS   AGE
fleetdm-xxx-xxx            1/1     Running   0          2m
fleetdm-xxx-xxx            1/1     Running   0          2m
fleetdm-mysql-0            1/1     Running   0          2m
fleetdm-redis-0            1/1     Running   0          2m
```

**Test FleetDM:**
```bash
kubectl run test --image=curlimages/curl --rm -i --restart=Never -n fleetdm \
  -- curl -f http://fleetdm:8080/healthz
# Should return HTTP 200
```

**Test MySQL:**
```bash
kubectl exec -n fleetdm fleetdm-mysql-0 -- mysqladmin ping -u root -pfleetroot
# Should return "mysqld is alive"
```

**Test Redis:**
```bash
kubectl exec -n fleetdm fleetdm-redis-0 -- redis-cli ping
# Should return "PONG"
```

Or use the built-in verify command:
```bash
make verify
```

## Access FleetDM UI

### Local Access

Port forward to access UI:
```bash
make port-forward
```
Then open http://localhost:8080

### Agent Reachability

FleetDM is exposed via NodePort 30080 and mapped to host port 8080.

**For Kind:**
```bash
curl http://localhost:8080/healthz
```

**For Minikube:**
```bash
minikube service fleetdm -n fleetdm
```

Agents can connect to FleetDM at the exposed URL.

## Configuration

Customize deployment by editing `helm/fleetdm/values.yaml`:

```yaml
fleetdm:
  replicaCount: 2
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi

mysql:
  persistence:
    size: 10Gi

redis:
  persistence:
    size: 5Gi
```

## Cleanup

Remove deployment:
```bash
make uninstall
```

Delete cluster:
```bash
make clean
```

## Makefile Targets

| Command | Description |
|---------|-------------|
| `make cluster` | Create local Kubernetes cluster |
| `make install` | Install FleetDM Helm chart |
| `make uninstall` | Remove all deployed resources |
| `make verify` | Check deployment status |
| `make port-forward` | Forward port to FleetDM UI |
| `make clean` | Delete cluster |
| `make logs-fleetdm` | View FleetDM logs |
| `make logs-mysql` | View MySQL logs |
| `make logs-redis` | View Redis logs |

## CI/CD Pipeline

GitHub Actions pipeline automatically:

### On Pull Requests
- Lints Helm chart
- Validates Kubernetes manifests
- Tests deployment on Kind cluster

### On Push to Main
- Runs full test suite
- Packages Helm chart
- Creates GitHub artifacts

### On Release
- Publishes chart package
- Creates release notes
- Uploads chart artifacts

View pipeline status in `.github/workflows/`.

## Troubleshooting

**Pods not starting:**
```bash
kubectl get events -n fleetdm --sort-by='.lastTimestamp'
kubectl logs -n fleetdm -l app.kubernetes.io/component=fleetdm
```

**Database issues:**
```bash
kubectl logs -n fleetdm -l app.kubernetes.io/component=db-init
```

**Can't access UI:**
```bash
kubectl get svc -n fleetdm
kubectl port-forward -n fleetdm svc/fleetdm 8080:8080
```

## Architecture

```
┌─────────────────────────────────────┐
│         FleetDM Application         │
│         (2 replicas)                │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
┌───────▼────┐  ┌─────▼──────┐
│  MySQL     │  │   Redis    │
│  (StatefulSet)│  │ (StatefulSet)│
│  10Gi PVC  │  │  5Gi PVC   │
└────────────┘  └────────────┘
```

Components:
- **FleetDM**: OSQuery fleet manager with web UI
- **MySQL 8.0**: Primary database with persistent storage
- **Redis 7.2**: Cache and session store
- **Init Job**: Automatically runs database migrations

## Notes

- Database initialization runs automatically on install
- StatefulSets ensure data persistence across pod restarts
- Default credentials in `values.yaml` should be changed for production
- TLS disabled by default for local development

## License

MIT
