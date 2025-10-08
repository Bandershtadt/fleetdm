# FleetDM Helm Chart

Production-ready Helm chart for deploying FleetDM (Fleet Device Management) on Kubernetes, with local development support using Kind.

## Overview

FleetDM is an open-source device management platform built on osquery that provides:
- **Device Inventory**: Comprehensive device discovery and management
- **Query Execution**: Real-time SQL-based queries across thousands of devices
- **Vulnerability Management**: Automated CVE detection and tracking
- **Policy Enforcement**: Compliance monitoring and policy automation

This Helm chart deploys:
- **FleetDM Server**: Main application server with high availability
- **MySQL**: Database for FleetDM data (Bitnami chart)
- **Redis**: Caching layer for query results (Bitnami chart)

## Prerequisites

### Local Development
- [Docker](https://docs.docker.com/get-docker/) - Container runtime
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) - Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Helm](https://helm.sh/docs/intro/install/) v3.x - Kubernetes package manager

### Production Deployment
- Kubernetes cluster (GKE, EKS, or AKS)
- Managed database service (Cloud SQL, RDS, etc.)
- Managed cache service (Cloud Memorystore, ElastiCache, etc.)

## Quick Start

### 1. Create Local Cluster

```bash
make cluster
```

This creates a Kind cluster with:
- Multi-node setup (1 control-plane + 2 workers)
- NGINX Ingress Controller
- Port forwarding for HTTP/HTTPS

### 2. Install FleetDM

```bash
make install
```

This will:
- Create the `fleetdm` namespace
- Install MySQL and Redis via Helm charts
- Deploy FleetDM with automatic database migration (`fleet prepare db`)
- Wait for all pods to be ready (with extended timeouts)

### 3. Access FleetDM

Add to your `/etc/hosts`:
```
127.0.0.1 fleet.localhost
```

Access FleetDM at: **http://fleet.localhost**

## Installation & Teardown Instructions

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd fleetdm
   ```

2. **Create the Kind cluster**:
   ```bash
   make cluster
   ```
   Wait for the NGINX Ingress Controller to be ready (~2 minutes).

3. **Install FleetDM**:
   ```bash
   make install
   ```
   Installation takes ~10-15 minutes due to database migrations.

4. **Verify installation**:
   ```bash
   make verify
   ```

### Teardown Steps

**Remove FleetDM only** (keep cluster):
```bash
make uninstall
```

**Remove everything** (including Kind cluster):
```bash
make clean
```

## Verification Steps

### Automated Verification

Run the built-in verification script:

```bash
make verify
```

This checks:
1. ✓ FleetDM pods are running
2. ✓ MySQL pods are running
3. ✓ Redis pods are running
4. ✓ FleetDM `/healthz` endpoint responds
5. ✓ Database connection is working

### Manual Verification

**Check pod status**:
```bash
kubectl get pods -n fleetdm
```

Expected output:
```
NAME                     READY   STATUS    RESTARTS   AGE
fleet-xxx-yyy            1/1     Running   0          5m
fleet-xxx-zzz            1/1     Running   0          5m
fleetdm-mysql-0          1/1     Running   0          5m
fleetdm-redis-master-0   1/1     Running   0          5m
```

**Test health endpoint**:
```bash
curl http://fleet.localhost/healthz
# Should return: {"status":"ok"}
```

**View logs**:
```bash
# FleetDM logs
kubectl logs -n fleetdm -l app=fleet --tail=50

# MySQL logs
kubectl logs -n fleetdm fleetdm-mysql-0 --tail=50

# Redis logs
kubectl logs -n fleetdm fleetdm-redis-master-0 --tail=50
```

**Port forward for direct access**:
```bash
kubectl port-forward -n fleetdm svc/fleetdm-service 8080:8080
# Access at http://localhost:8080
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make cluster` | Create Kind cluster with NGINX Ingress |
| `make install` | Install FleetDM Helm chart |
| `make uninstall` | Remove FleetDM deployment |
| `make clean` | Delete Kind cluster |
| `make verify` | Run verification tests |
| `make status` | Show pod status |
| `make logs` | View FleetDM logs |
| `make port-forward` | Forward FleetDM service to localhost:8080 |
| `make help` | Show all available targets |

## CI/CD Pipeline

A GitHub Actions workflow is included for automated Helm chart releases:

**Workflow**: `.github/workflows/ci.yml`

**Triggers**:
- Push to `main` branch
- Git tags matching `v*.*.*`

**Pipeline Steps**:
1. Checkout code
2. Set up Helm
3. Lint Helm chart (`helm lint`)
4. Package Helm chart
5. Create GitHub Release with chart artifact
6. (Optional) Publish to Helm repository

**Additional Workflows**:
- `.github/workflows/lint.yml` - YAML and Helm linting on PRs
- Runs `helm lint` and `yamllint` on all chart files

## Configuration

### Key Configuration Options

Edit `fleet/values.yaml` to customize:

```yaml
# FleetDM replicas
replicas: 3

# Resource limits
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  host: fleet.localhost

# MySQL configuration
mysql:
  enabled: true
  primary:
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi

# Redis configuration
redis:
  enabled: true
  image:
    repository: redis
    tag: "7.2-alpine"
```

### Database Migration

The database migration (`fleet prepare db`) runs automatically on installation via a Kubernetes Job:
- Template: `fleet/templates/job-migration.yaml`
- Hook: `helm.sh/hook: post-install,post-upgrade`
- Ensures FleetDM database schema is up-to-date before pods start

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                 Internet / Localhost                  │
└───────────────────────┬──────────────────────────────┘
                        │
                 ┌──────▼─────┐
                 │   Ingress  │
                 │   (NGINX)  │
                 └──────┬─────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
     ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
     │ Fleet   │   │ Fleet   │   │ Fleet   │
     │ Pod 1   │   │ Pod 2   │   │ Pod 3   │
     └────┬────┘   └────┬────┘   └────┬────┘
          │             │             │
          └─────────────┼─────────────┘
                        │
          ┌─────────────┴─────────────┐
          │                           │
     ┌────▼────┐                 ┌────▼────┐
     │  MySQL  │                 │  Redis  │
     │ (Bitnami│                 │(Bitnami)│
     │  Chart) │                 │ Chart)  │
     └─────────┘                 └─────────┘
```

## Production Deployment

For production deployments, see the [detailed architecture guide](docs/architecture.md) which covers:
- Multi-environment setup (Dev/Staging/Prod)
- External managed databases (Cloud SQL, RDS)
- High availability and scaling
- Security best practices (TLS, network policies, RBAC)
- Monitoring and observability
- Cost optimization strategies

### Quick Production Tips

1. **Use external managed services**:
   ```yaml
   mysql:
     enabled: false  # Use Cloud SQL or RDS
   redis:
     enabled: false  # Use Memorystore or ElastiCache
   ```

2. **Enable TLS**:
   ```yaml
   fleet:
     tls:
       enabled: true
       certManager: true
   ```

3. **Configure autoscaling**:
   ```yaml
   autoscaling:
     enabled: true
     minReplicas: 3
     maxReplicas: 10
   ```

## Troubleshooting

### Common Issues

**1. Pods not starting**:
```bash
kubectl describe pods -n fleetdm
kubectl logs -n fleetdm <pod-name>
```

**2. Timeout during installation**:
- Database migrations can take 5-10 minutes
- Increase timeout: `helm install --timeout=20m`

**3. Ingress not working**:
```bash
# Check ingress status
kubectl get ingress -n fleetdm
kubectl describe ingress -n fleetdm

# Verify /etc/hosts entry
ping fleet.localhost
```

**4. Port conflicts**:
- Ensure ports 80, 443, 8080 are available
- Check for other Kind clusters: `kind get clusters`

**5. Redis/MySQL image pull failures**:
- Bitnami images changed access policy (Sept 2025)
- Chart uses official Docker images with Bitnami Helm charts
- Check `values.yaml` for image overrides

### Reset Everything

If you encounter persistent issues:
```bash
make clean
make cluster
make install
```

## Development

### Local Development Workflow

```bash
# Start cluster and install
make cluster
make install

# Make changes to chart
vim fleet/values.yaml

# Upgrade deployment
helm upgrade fleetdm ./fleet -n fleetdm

# View logs
make logs

# Clean up
make clean
```

### Custom Values

Create `custom-values.yaml`:
```yaml
replicas: 1
resources:
  limits:
    cpu: 500m
    memory: 1Gi
```

Install with custom values:
```bash
helm install fleetdm ./fleet -n fleetdm -f custom-values.yaml
```

## FleetDM Agent Configuration

Once FleetDM is running, configure agents to connect:

1. **Get enrollment secret**:
   ```bash
   kubectl exec -n fleetdm deployment/fleet -- \
     fleet get enroll-secrets
   ```

2. **Install osquery on endpoints**:
   ```bash
   # macOS/Linux
   curl -L https://osquery.io/downloads | bash
   
   # Configure osquery to connect
   osqueryd --flagfile=/path/to/osquery.flags \
     --enroll_secret_path=/path/to/secret
   ```

3. **Verify in FleetDM UI**:
   - Navigate to http://fleet.localhost
   - Go to "Hosts" to see connected devices

## Resources

- [FleetDM Official Documentation](https://fleetdm.com/docs)
- [FleetDM GitHub Repository](https://github.com/fleetdm/fleet)
- [FleetDM Infrastructure Examples](https://github.com/fleetdm/fleet/tree/main/infrastructure)
- [FleetDM Community Slack](https://fleetdm.com/slack)
- [Architectural Design Document](docs/architecture.md)

## License

This Helm chart is provided as-is for demonstration and production use. FleetDM is licensed under the MIT License.

---

**Note**: This project was created as part of a DevOps assignment demonstrating Kubernetes, Helm, and infrastructure automation best practices.
