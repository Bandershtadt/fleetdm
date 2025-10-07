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


---
# Cloud Architecture - Company Inc. (Detailed Design)

This document expands on the high-level overview to address provider choice, environment structure, network and compute design, containerization, CI/CD, and database/DR strategy as required.

## 1. Cloud Environment Structure and Provider Choice

- Provider: GCP (justification)
  - Managed Kubernetes maturity (GKE Autopilot/Standard), strong autoscaling and cost controls.
  - First-class private networking (Private GKE, Private Service Connect), Cloud Armor WAF, global load balancer/CDN.
  - Integrated developer workflow (Artifact Registry, Cloud Build/Deploy, Secret Manager, Cloud Monitoring).
  - Alternative: AWS (EKS + ALB/WAF + PrivateLink + CodeBuild/CodePipeline) is viable; choose per team expertise and vendor alignment. GCP chosen here for simplicity and Autopilot efficiency.

- Projects (organizations/accounts) for isolation and billing:
  1) company-inc-dev — developer sandbox, lower quotas, looser policies.
  2) company-inc-staging — production-like validation (soak tests, security parity).
  3) company-inc-prod — production only, strict controls, break-glass access.
  4) company-inc-shared — shared services (Artifact Registry, CI runners, monitoring, logging, IAM groups).
  - Rationale: blast-radius isolation, clean billing boundaries, per‑environment IAM policies, promotion controls.

## 2. Network Design (VPC)

- Per project VPC: 10.0.0.0/8 supernet split into environment CIDRs (e.g., prod 10.1.0.0/16, staging 10.2.0.0/16, dev 10.3.0.0/16).
- Subnets per region/zone: dedicated subnets for nodes and pods (GKE manages pod ranges); private clusters (no public node IPs), control plane authorized networks.
- Ingress:
  - HTTP(S) Global Load Balancer → GKE Ingress (NEG) → Services.
  - Cloud CDN for SPA static assets.
- Egress: Cloud NAT for controlled outbound access; restrict egress with firewall + VPC Service Controls where applicable.
- Security:
  - Firewall rules: allow only LB health checks to NodePorts, block all else by default.
  - Kubernetes NetworkPolicies: default deny; allow namespace/service specific traffic (frontend→backend, backend→MongoDB Atlas proxy/PE).
  - Private connectivity to MongoDB Atlas via VPC peering or Private Service Connect; no public IP for DB.

## 3. Compute Platform (GKE)

- Clusters:
  - Prod: GKE Autopilot, regional (3 zones), private cluster, Workload Identity.
  - Staging: GKE Standard, 2–3 zones, similar settings but smaller.
  - Dev: GKE Standard, single/multi-zone, preemptible node pool for savings.
- Node pools (Standard clusters):
  - System pool (n2-standard-2), Workload pool(s):
    - frontend (e2-standard-2), backend (e2-standard-4 with CPU boost), jobs (e2-standard-2, preemptible allowed for non-critical).
- Scaling:
  - HPA for frontend and backend based on CPU/memory and latency SLI; min/max per environment.
  - VPA in “recommendation” mode; consider Autopilot for prod to offload binpacking.
  - Resource requests/limits enforced; PodDisruptionBudgets for HA.
- Multi-tenancy and controls:
  - Namespaces: frontend, backend, shared (redis), platform (ingress, cert-manager), tools.
  - Quotas/LimitRanges per namespace; OPA/Gatekeeper policies for best practices.
- Observability: Cloud Monitoring/Logging, SLO 99.9% with alerting (latency, errors, saturation), Cloud Trace/Profiler.

## 4. Containerization and CI/CD

- Containerization:
  - Backend (Flask): multi-stage Dockerfile (builder installs deps, runtime uses slim Python), gunicorn, non-root user.
  - Frontend (React): build to static assets, served via nginx or Cloud Storage/Cloud CDN; cache busting.
  - Security: minimal base images (distroless/alpine where safe), pinned versions, SBOM (syft), vulnerability scans.
- Registry Management: Artifact Registry (regional), immutable tags with SHA digests; lifecycle policies to clean old images.
- CI/CD:
  - CI: GitHub Actions with OIDC to GCP (no long‑lived keys). Steps: lint → test → build images → push to Artifact Registry → scan → sign with cosign.
  - CD: Argo CD (GitOps) or Cloud Deploy; Helm charts per service; progressive delivery (canary/blue‑green) via Service mesh (optional) or native.
  - Promotion: PR-based environment promotion; only artifacts from staged releases can reach prod; policies enforced with approvals.

## 5. Database (MongoDB Atlas)

- Service: MongoDB Atlas (M40 to start, auto-scale; shard when needed). Private peering to VPC; IP access list locked down to GKE only.
- Backups: Continuous (PITR 7 days) + snapshot schedules (6h/30d, daily/90d, weekly/1y). Test restores quarterly.
- High Availability: 3-node replica set across 3 zones (primary/secondaries). Enable election timeout tuning for fast failover.
- Disaster Recovery: Cross-region read-only node or continuous cloud backup with periodic cross-region snapshot copy. RPO ≤ 15 min, RTO ≤ 1 h initial, tighten as scale/budget allow.
- Secrets: App credentials in Secret Manager, mounted via Workload Identity + CSI driver; rotate quarterly or upon incident.

## 6. Security & Compliance

- TLS everywhere; managed certs on LB; mTLS inside cluster if using service mesh.
- Workload Identity, no node/project-wide service keys. Least-privilege IAM roles per project.
- Image policy: only signed images from Artifact Registry; admission controller to enforce.
- Audit: Admin Activity and Data Access logs enabled; retention per compliance.

## 7. Cost Management

- Use Autopilot in prod to reduce ops overhead; Standard + preemptibles in non-prod.
- Budgets/alerts per project; label/trace costs per service; autoscaling and CDN to minimize compute and egress.

---
