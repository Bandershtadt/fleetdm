# Cloud Architecture - Company Inc.

Web app deployment on GCP (Flask + React + MongoDB).

## Tech Stack

- **Cloud**: GCP
- **Compute**: GKE Autopilot  
- **Database**: MongoDB Atlas
- **CDN**: Cloud CDN

## Project Structure

4 GCP projects for isolation:
- dev, staging, prod, shared

## Network

- Private GKE cluster
- VPC peering to MongoDB
- Cloud Armor for security
- Global load balancer with CDN

## GKE Setup

**Production**:
- GKE Autopilot (auto-managed)
- 3 zones for HA
- HPA: 3-50 frontend, 5-100 backend
- Private nodes, workload identity

**Dev/Staging**:
- Standard GKE
- Preemptible nodes for cost savings

## Database

**MongoDB Atlas M40**:
- 3-node replica set
- VPC peering to GKE
- Auto backups (PITR + snapshots)
- Scale to M60+ as needed

Backups:
- Continuous: 7 days
- Snapshots: 6hr/30 days, daily/90 days
- Cross-region weekly/1 year

## Security

- TLS everywhere
- Workload Identity (no keys)
- Secret Manager
- Cloud Armor WAF
- Private networking
- Audit logs

## Monitoring

Cloud Monitoring + Logging:
- SLO: 99.9% uptime
- Alerts for errors/downtime
- Cloud Trace for requests

## Costs

| Users/Day | Monthly Cost |
|-----------|--------------|
| 1K        | ~$650        |
| 10K       | ~$1,500      |
| 100K      | ~$5,000      |
| 1M        | ~$20,000     |

Optimization:
- Committed discounts
- Autoscaling
- CDN caching
- Preemptible for non-prod

## Implementation

1. Setup projects & networking
2. Deploy dev/staging
3. Set up CI/CD
4. Launch production

See diagram files for visuals.

