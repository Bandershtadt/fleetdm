.PHONY: help cluster cluster-kind cluster-minikube install uninstall verify clean package lint

# Default cluster type (kind or minikube)
CLUSTER_TYPE ?= kind
CLUSTER_NAME ?= fleetdm-cluster
NAMESPACE ?= fleetdm
CHART_PATH := ./helm/fleetdm
RELEASE_NAME := fleetdm

help: ## Display this help message
	@echo "FleetDM Kubernetes Deployment"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

cluster: cluster-$(CLUSTER_TYPE) ## Create local Kubernetes cluster (default: kind, use CLUSTER_TYPE=minikube to override)

cluster-kind: ## Create a Kind cluster
	@echo "Creating Kind cluster..."
	@if kind get clusters | grep -q $(CLUSTER_NAME); then \
		echo "Cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config ./config/kind-config.yaml; \
		kubectl cluster-info --context kind-$(CLUSTER_NAME); \
	fi

cluster-minikube: ## Create a Minikube cluster
	@echo "Creating Minikube cluster..."
	@if minikube status -p $(CLUSTER_NAME) >/dev/null 2>&1; then \
		echo "Cluster $(CLUSTER_NAME) already exists"; \
	else \
		minikube start --profile $(CLUSTER_NAME) --cpus=4 --memory=8192 --disk-size=20g --driver=docker; \
		kubectl config use-context $(CLUSTER_NAME); \
	fi

install: ## Install the FleetDM Helm chart
	@echo "Creating namespace $(NAMESPACE)..."
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "Installing FleetDM Helm chart..."
	@helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 10m \
		--create-namespace
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "To access FleetDM UI:"
	@if [ "$(CLUSTER_TYPE)" = "kind" ]; then \
		echo "  kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-fleetdm 8080:8080"; \
	else \
		echo "  minikube service $(RELEASE_NAME)-fleetdm -n $(NAMESPACE)"; \
	fi
	@echo ""
	@echo "Then visit: http://localhost:8080"

uninstall: ## Remove all deployed resources
	@echo "Uninstalling FleetDM..."
	@helm uninstall $(RELEASE_NAME) -n $(NAMESPACE) || true
	@echo "Deleting namespace..."
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "Cleanup complete!"

verify: ## Verify that all components are running
	@echo "Verifying FleetDM deployment..."
	@echo ""
	@echo "=== Namespace ==="
	@kubectl get namespace $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "=== PVCs ==="
	@kubectl get pvc -n $(NAMESPACE)
	@echo ""
	@echo "=== Jobs ==="
	@kubectl get jobs -n $(NAMESPACE)
	@echo ""
	@echo "=== Deployment Status ==="
	@kubectl rollout status deployment/$(RELEASE_NAME)-fleetdm -n $(NAMESPACE) --timeout=30s || true
	@kubectl rollout status deployment/$(RELEASE_NAME)-mysql -n $(NAMESPACE) --timeout=30s || true
	@kubectl rollout status deployment/$(RELEASE_NAME)-redis -n $(NAMESPACE) --timeout=30s || true

clean: ## Delete the local cluster
	@echo "Deleting $(CLUSTER_TYPE) cluster..."
	@if [ "$(CLUSTER_TYPE)" = "kind" ]; then \
		kind delete cluster --name $(CLUSTER_NAME); \
	else \
		minikube delete --profile $(CLUSTER_NAME); \
	fi

package: ## Package the Helm chart
	@echo "Packaging Helm chart..."
	@helm package $(CHART_PATH) -d ./dist
	@echo "Chart packaged successfully!"

lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	@helm lint $(CHART_PATH)

all: cluster install verify ## Create cluster, install, and verify (full setup)

logs-fleetdm: ## Show FleetDM logs
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=fleetdm --tail=100 -f

logs-mysql: ## Show MySQL logs
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=mysql --tail=100 -f

logs-redis: ## Show Redis logs
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=redis --tail=100 -f

logs-db-init: ## Show database init job logs
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=db-init --tail=100

port-forward: ## Port-forward to FleetDM UI
	@echo "Forwarding port 8080 to FleetDM service..."
	@kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-fleetdm 8080:8080

test: ## Run Helm tests
	@echo "Running Helm tests..."
	@helm test $(RELEASE_NAME) -n $(NAMESPACE) --timeout 5m

test-connection: ## Test service connectivity
	@echo "Testing service connectivity..."
	@kubectl run test-connection --image=busybox:1.35 --rm -i --restart=Never -- \
		sh -c "nc -z $(RELEASE_NAME)-fleetdm 8080 && nc -z $(RELEASE_NAME)-mysql 3306 && nc -z $(RELEASE_NAME)-redis 6379 && echo 'All services accessible'"

test-database: ## Test database connectivity
	@echo "Testing database connectivity..."
	@kubectl run test-database --image=mysql:8.0.36 --rm -i --restart=Never --env="MYSQL_PWD=fleetpassword" -- \
		mysql -h $(RELEASE_NAME)-mysql -u fleet -e "SELECT 1" fleet

