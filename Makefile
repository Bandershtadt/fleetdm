# FleetDM Helm Chart Makefile
# This Makefile provides targets for managing a local Kubernetes cluster and FleetDM deployment

# Variables
CLUSTER_NAME ?= fleetdm-cluster
NAMESPACE ?= fleetdm
CHART_PATH ?= ./fleet
RELEASE_NAME ?= fleetdm

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help cluster install uninstall status logs clean

help: ## Show this help message
	@echo "FleetDM Helm Chart Management"
	@echo "============================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

cluster: ## Create local Kubernetes cluster using Kind
	@echo "$(YELLOW)Creating Kind cluster: $(CLUSTER_NAME)$(NC)"
	@if kind get clusters | grep -q $(CLUSTER_NAME); then \
		echo "$(YELLOW)Cluster $(CLUSTER_NAME) already exists$(NC)"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config config/kind-config.yaml; \
		echo "$(GREEN)Cluster $(CLUSTER_NAME) created successfully$(NC)"; \
	fi
	@echo "$(YELLOW)Installing NGINX Ingress Controller$(NC)"
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "$(YELLOW)Waiting for NGINX Ingress Controller to be ready...$(NC)"
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s
	@echo "$(GREEN)NGINX Ingress Controller is ready$(NC)"

install: ## Install FleetDM Helm chart
	@echo "$(YELLOW)Installing FleetDM Helm chart...$(NC)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@helm dependency update $(CHART_PATH)
	@helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout=5m
	@echo "$(GREEN)FleetDM installed successfully$(NC)"
	@echo "$(YELLOW)Waiting for migration jobs to complete...$(NC)"
	@kubectl wait --for=condition=complete job -l app.kubernetes.io/component=migration -n $(NAMESPACE) --timeout=600s || echo "$(YELLOW)Migration job timeout - continuing with deployment$(NC)"
	@echo "$(YELLOW)Waiting for all pods to be ready...$(NC)"
	@kubectl wait --for=condition=ready pod -l app=fleet -n $(NAMESPACE) --timeout=600s
	@echo "$(GREEN)All pods are ready$(NC)"
	@echo ""
	@echo "$(GREEN)FleetDM is accessible at: http://fleet.localhost$(NC)"
	@echo "$(YELLOW)Add '127.0.0.1 fleet.localhost' to your /etc/hosts file if not already present$(NC)"

uninstall: ## Remove FleetDM deployment and all resources
	@echo "$(YELLOW)Uninstalling FleetDM...$(NC)"
	@helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)FleetDM uninstalled successfully$(NC)"

status: ## Show status of FleetDM deployment
	@echo "$(YELLOW)FleetDM Deployment Status:$(NC)"
	@echo "================================"
	@kubectl get pods -n $(NAMESPACE) -l app=fleet
	@echo ""
	@echo "$(YELLOW)Services:$(NC)"
	@kubectl get services -n $(NAMESPACE)
	@echo ""
	@echo "$(YELLOW)Ingress:$(NC)"
	@kubectl get ingress -n $(NAMESPACE)
	@echo ""
	@echo "$(YELLOW)MySQL Status:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=mysql
	@echo ""
	@echo "$(YELLOW)Redis Status:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=redis

logs: ## Show logs from FleetDM pods
	@echo "$(YELLOW)FleetDM Logs:$(NC)"
	@kubectl logs -n $(NAMESPACE) -l app=fleet --tail=50

clean: ## Remove Kind cluster
	@echo "$(YELLOW)Removing Kind cluster: $(CLUSTER_NAME)$(NC)"
	@kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "$(GREEN)Cluster removed$(NC)"

verify: ## Verify FleetDM, MySQL, and Redis are operational
	@echo "$(YELLOW)Verifying FleetDM deployment...$(NC)"
	@echo "====================================="
	@echo ""
	@echo "$(YELLOW)1. Checking FleetDM pods:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app=fleet
	@echo ""
	@echo "$(YELLOW)2. Checking MySQL pods:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=mysql
	@echo ""
	@echo "$(YELLOW)3. Checking Redis pods:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=redis
	@echo ""
	@echo "$(YELLOW)4. Testing FleetDM health endpoint:$(NC)"
	@kubectl port-forward -n $(NAMESPACE) svc/fleetdm-service 8080:8080 &
	@PF_PID=$$!; \
	sleep 5; \
	if curl -f http://localhost:8080/healthz > /dev/null 2>&1; then \
		echo "$(GREEN)✓ FleetDM health check passed$(NC)"; \
	else \
		echo "$(RED)✗ FleetDM health check failed$(NC)"; \
	fi; \
	kill $$PF_PID 2>/dev/null || true
	@echo ""
	@echo "$(YELLOW)5. Testing MySQL connection:$(NC)"
	@kubectl exec -n $(NAMESPACE) deployment/fleet -- fleet prepare db --no-prompt || echo "$(RED)✗ MySQL connection test failed$(NC)"
	@echo ""
	@echo "$(GREEN)Verification complete!$(NC)"

port-forward: ## Port forward FleetDM service to localhost:8080
	@echo "$(YELLOW)Port forwarding FleetDM to localhost:8080...$(NC)"
	@echo "$(GREEN)FleetDM will be available at: http://localhost:8080$(NC)"
	@kubectl port-forward -n $(NAMESPACE) svc/fleetdm-service 8080:8080
