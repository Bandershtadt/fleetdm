# FleetDM Kubernetes Deployment

Helm chart for running FleetDM on Kubernetes with MySQL and Redis.

## Prerequisites

- Docker
- kubectl
- Helm 3
- Kind or Minikube

## Quick Start

```bash
# Create cluster
make cluster

# Install
make install

# Check status
make verify

# Access UI
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

This deploys:
- FleetDM server (2 replicas)
- MySQL 8.0 with persistent storage
- Redis 7.2 with persistent storage

### 3. Verify Deployment

Check all pods are running:
```bash
kubectl get pods -n fleetdm
```

Expected output:
```
NAME                       READY   STATUS      RESTARTS   AGE
fleetdm-xxx                1/1     Running     0          2m
fleetdm-xxx                1/1     Running     0          2m
fleetdm-mysql-xxx          1/1     Running     0          2m
fleetdm-redis-xxx          1/1     Running     0          2m
fleetdm-db-init-xxx        0/1     Completed   0          2m
```

Verify each component:

**FleetDM**:
```bash
kubectl logs -n fleetdm -l app.kubernetes.io/component=fleetdm --tail=20
# Should show "listening" on port 8080
```

**MySQL**:
```bash
kubectl exec -n fleetdm deployment/fleetdm-mysql -- mysqladmin ping
# Should return "mysqld is alive"
```

**Redis**:
```bash
kubectl exec -n fleetdm deployment/fleetdm-redis -- redis-cli ping
# Should return "PONG"
```

Or use the verify command:
```bash
make verify
```

## Access FleetDM

### Port Forward
```bash
make port-forward
```
Then open http://localhost:8080

### Direct NodePort
For Kind with port mapping:
```bash
open http://localhost:8080
```

## Configuration

Edit `helm/fleetdm/values.yaml` to customize:

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

```
make cluster      - Create local k8s cluster
make install      - Install helm chart
make uninstall    - Remove all resources
make verify       - Check deployment status
make port-forward - Forward port to FleetDM UI
make clean        - Delete cluster
make logs-fleetdm - View FleetDM logs
make logs-mysql   - View MySQL logs
make logs-redis   - View Redis logs
```

## Troubleshooting

### Pods not starting

Check events:
```bash
kubectl get events -n fleetdm --sort-by='.lastTimestamp'
```

Check logs:
```bash
kubectl logs -n fleetdm -l app.kubernetes.io/component=fleetdm
```

### Database issues

Check MySQL:
```bash
kubectl exec -n fleetdm deployment/fleetdm-mysql -- mysqladmin ping
```

Check db-init job:
```bash
kubectl logs -n fleetdm -l app.kubernetes.io/component=db-init
```

### Can't access UI

Verify service:
```bash
kubectl get svc -n fleetdm
```

Test port forward:
```bash
kubectl port-forward -n fleetdm svc/fleetdm 8080:8080
```

## Architecture

The deployment includes:

- **FleetDM**: Osquery fleet manager
- **MySQL**: Primary database
- **Redis**: Cache and session store
- **Init Job**: Runs `fleet prepare db` automatically

All components use persistent storage and have health checks configured.

## Notes

- Default passwords are in `values.yaml` - change for production
- TLS is disabled by default for local dev
- Database is auto-initialized on first install
- For production, enable ingress and proper TLS

## License

MIT
