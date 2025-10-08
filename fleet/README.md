# Fleet Helm Chart

This Helm chart deploys FleetDM on Kubernetes with MySQL and Redis dependencies.

## Features

- ✅ FleetDM Server deployment with configurable replicas
- ✅ MySQL database (Bitnami chart) with persistent storage
- ✅ Redis cache (Bitnami chart) for query caching
- ✅ Automatic database migration on install/upgrade
- ✅ NGINX Ingress support
- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ Resource limits and requests
- ✅ Configurable via `values.yaml`

## Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.x
- kubectl configured

## Quick Install

```bash
# Create namespace
kubectl create namespace fleetdm

# Install chart
helm install fleetdm ./fleet --namespace fleetdm
```

## Configuration

### Key Values

Edit `values.yaml` to customize:

```yaml
# Number of FleetDM replicas
replicas: 3

# FleetDM image
image:
  repository: fleetdm/fleet
  tag: v4.74.0

# Resources
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

# Ingress
ingress:
  enabled: true
  className: "nginx"
  host: fleet.localhost

# MySQL (Bitnami chart)
mysql:
  enabled: true
  primary:
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi

# Redis (Bitnami chart)  
redis:
  enabled: true
  image:
    repository: redis
    tag: "7.2-alpine"
```

## Database Migration

The chart automatically runs `fleet prepare db` via a Kubernetes Job:
- Runs as a Helm hook on `post-install` and `post-upgrade`
- Located in `templates/job-migration.yaml`
- Ensures database schema is up-to-date before FleetDM pods start

## Dependencies

This chart depends on:
- **MySQL**: Bitnami MySQL chart (v9.12.5)
- **Redis**: Bitnami Redis chart (v18.1.6)

Dependencies are defined in `Chart.yaml` and managed via:

```bash
helm dependency update
```

## Usage

### Install with Default Values

```bash
helm install fleetdm ./fleet -n fleetdm --create-namespace
```

### Install with Custom Values

Create `custom-values.yaml`:

```yaml
replicas: 1
resources:
  limits:
    cpu: 500m
    memory: 1Gi
```

Install:

```bash
helm install fleetdm ./fleet -n fleetdm -f custom-values.yaml
```

### Upgrade

```bash
helm upgrade fleetdm ./fleet -n fleetdm
```

### Uninstall

```bash
helm uninstall fleetdm -n fleetdm
```

## Production Deployment

For production, consider:

1. **Use External Databases**:
   ```yaml
   mysql:
     enabled: false
   redis:
     enabled: false
   
   fleet:
     database:
       address: "cloud-sql-proxy:3306"
       secretName: "cloud-sql-credentials"
     cache:
       address: "memorystore-redis:6379"
   ```

2. **Enable TLS**:
   ```yaml
   fleet:
     tls:
       enabled: true
   ```

3. **Configure Autoscaling**:
   ```yaml
   autoscaling:
     enabled: true
     minReplicas: 3
     maxReplicas: 10
   ```

4. **Set Resource Limits**:
   ```yaml
   resources:
     limits:
       cpu: 2000m
       memory: 4Gi
     requests:
       cpu: 1000m
       memory: 2Gi
   ```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n fleetdm
```

### View Logs

```bash
kubectl logs -n fleetdm -l app=fleet
```

### Check Migration Job

```bash
kubectl get jobs -n fleetdm
kubectl logs -n fleetdm job/fleet-migration-xxxxx
```

### Exec into Pod

```bash
kubectl exec -it -n fleetdm deployment/fleet -- /bin/sh
```

## Chart Structure

```
fleet/
├── Chart.yaml              # Chart metadata and dependencies
├── Chart.lock              # Dependency lock file
├── values.yaml             # Default configuration values
├── templates/
│   ├── _helpers.tpl        # Template helpers
│   ├── deployment.yaml     # FleetDM Deployment
│   ├── service.yaml        # FleetDM Service
│   ├── ingress.yaml        # Ingress for external access
│   ├── job-migration.yaml  # Database migration job
│   ├── sa.yaml             # ServiceAccount
│   ├── rbac.yaml           # RBAC resources
│   ├── cron-vulnprocessing.yaml  # Vulnerability processing cronjob
│   └── gke-managedcertificate.yaml  # GKE SSL certificate
└── charts/                 # Dependency charts (MySQL, Redis)
```

## Resources

- [FleetDM Documentation](https://fleetdm.com/docs)
- [FleetDM GitHub](https://github.com/fleetdm/fleet)
- [Official Fleet Helm Chart](https://github.com/fleetdm/fleet/tree/main/charts/fleet)

## License

This Helm chart is based on the official FleetDM chart and provided as-is.
