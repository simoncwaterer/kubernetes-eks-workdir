IMAGE_NAME = explorecalifornia.com
CONTAINER_NAME = $(IMAGE_NAME)
HOST_PORT = 4000
CONTAINER_PORT = 80

# Kind configuration
KIND_VERSION = 0.24.0
PLATFORM_OS = $(shell uname -s | tr A-Z a-z)
PLATFORM_ARCH = $(shell uname -m | sed 's/x86_64/amd64/')
KIND_BINARY = ./kind
KIND_URL = https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-$(PLATFORM_OS)-$(PLATFORM_ARCH)
INSTALL_PATH = /usr/local/bin/kind
KIND_CLUSTER_NAME = explorecalifornia
KIND_CONFIG_FILE = kind-config.yaml

# Registry configuration
REGISTRY_NAME := local-registry
REGISTRY_PORT := 6000

# Check if container is running
CONTAINER_RUNNING := $(shell docker ps --format '{{.Names}}' | grep -q '^$(CONTAINER_NAME)$$' && echo 1 || echo 0)

# Phony targets (targets that don't create files)
.PHONY: help run_website stop_website status_website kind_install kind_cluster_create \
	kind_cluster_delete registry-create registry-delete registry-status \
	registry-test kind_config_generate kind_config_clean registry_connect push_website \
	kind_install_ingress

run_website:
ifeq ($(CONTAINER_RUNNING),1)
	@echo "Container '$(CONTAINER_NAME)' is already running"
else
	docker build -t $(IMAGE_NAME) . && \
		docker run --rm -d -p $(HOST_PORT):$(CONTAINER_PORT) --name $(CONTAINER_NAME) $(IMAGE_NAME)
	@echo "Container '$(CONTAINER_NAME)' started on port $(HOST_PORT)"
endif

stop_website:
ifeq ($(CONTAINER_RUNNING),1)
	docker stop $(CONTAINER_NAME)
	@echo "Container '$(CONTAINER_NAME)' stopped"
else
	@echo "Container '$(CONTAINER_NAME)' is not running"
endif

status_website:
ifeq ($(CONTAINER_RUNNING),1)
	@echo "Container '$(CONTAINER_NAME)' is running on port $(HOST_PORT)"
else
	@echo "Container '$(CONTAINER_NAME)' is not running"
endif

KIND_INSTALLED := $(shell which kind 2>/dev/null)

kind_install:
ifdef KIND_INSTALLED
	@echo "Kind is already installed at: $(KIND_INSTALLED)"
	@kind --version
else
	@echo "Downloading Kind v$(KIND_VERSION) for $(PLATFORM_OS)-$(PLATFORM_ARCH)..."
	@curl -Lo $(KIND_BINARY) $(KIND_URL)
	@chmod +x $(KIND_BINARY)
	@if [ -w /usr/local/bin ]; then \
		echo "Moving Kind to $(INSTALL_PATH)"; \
		mv $(KIND_BINARY) $(INSTALL_PATH); \
	elif command -v sudo >/dev/null 2>&1; then \
		echo "Moving Kind to $(INSTALL_PATH) (requires sudo)"; \
		sudo mv $(KIND_BINARY) $(INSTALL_PATH); \
	else \
		echo "Cannot write to $(INSTALL_PATH). Installing to $(USER_BIN) instead"; \
		mkdir -p $(USER_BIN); \
		mv $(KIND_BINARY) $(USER_BIN)/kind; \
		echo "Please add $(USER_BIN) to your PATH if not already added"; \
	fi
	@echo "Verifying installation..."
	@kind --version || $(USER_BIN)/kind --version
	@echo "Kind installation complete!"
endif

KUBECTL_INSTALLED := $(shell which kubectl 2>/dev/null)

kubectl_install:
ifdef KUBECTL_INSTALLED
	@echo "Kubectl is already installed at: $(KIND_INSTALLED)"
	kubectl version --client
else
	@echo "Installing kubectl with homebrew"
	@brew install kubectl
endif

# Create local registry
registry_create:
	@if [ -z "$$(docker ps -q -f name=$(REGISTRY_NAME))" ]; then \
		echo "Creating local registry container..."; \
		docker run -d \
			--name $(REGISTRY_NAME) \
			--restart=always \
			-p $(REGISTRY_PORT):5000 \
			registry:2; \
		echo "Please configure Docker Desktop to allow insecure registries..."; \
		echo "Go to Docker Desktop > Preferences > Docker Engine and add the following:"; \
		echo '{"insecure-registries":["localhost:$(REGISTRY_PORT)"]}'; \
		echo "Then restart Docker Desktop to apply changes."; \
		echo "Registry created successfully at localhost:$(REGISTRY_PORT)"; \
	else \
		echo "Registry already exists"; \
	fi
	
# Delete local registry
registry_delete:
	@if [ ! -z "$$(docker ps -aq -f name=$(REGISTRY_NAME))" ]; then \
		echo "Removing registry container..."; \
		docker rm -f $(REGISTRY_NAME); \
		echo "Registry removed successfully"; \
	else \
		echo "Registry does not exist"; \
	fi

# Check registry status
registry_status:
	@if [ ! -z "$$(docker ps -q -f name=$(REGISTRY_NAME))" ]; then \
		echo "Registry is running at localhost:$(REGISTRY_PORT)"; \
		echo "Container details:"; \
		docker ps -f name=$(REGISTRY_NAME); \
	else \
		echo "Registry is not running"; \
	fi

# Test registry by pushing a test image
registry_test:
	@echo "Testing registry with nginx image..."
	@docker pull nginx:latest
	@docker tag nginx:latest localhost:$(REGISTRY_PORT)/nginx:latest
	@docker push localhost:$(REGISTRY_PORT)/nginx:latest
	@echo "Test complete - nginx image pushed successfully"

# Push explorecalifornia.com to local registry
push_website:
	@echo "Push explorecalifornia.com image to local registry"
	@docker tag $(IMAGE_NAME) localhost:$(REGISTRY_PORT)/$(IMAGE_NAME)
	@docker push localhost:$(REGISTRY_PORT)/$(IMAGE_NAME)

# Check if cluster exists
KIND_CLUSTER_EXISTS := $(shell kind get clusters 2>/dev/null | grep -q '^$(KIND_CLUSTER_NAME)$$' && echo 1 || echo 0)

# Generate Kind configuration file
kind_config_generate:
	@if [ ! -z "$$(docker ps -q -f name=$(REGISTRY_NAME))" ]; then \
		echo "Generating Kind configuration with local registry and ingress support..." && \
		echo "kind: Cluster" > $(KIND_CONFIG_FILE) && \
		echo "apiVersion: kind.x-k8s.io/v1alpha4" >> $(KIND_CONFIG_FILE) && \
		echo "name: $(KIND_CLUSTER_NAME)" >> $(KIND_CONFIG_FILE) && \
		echo "containerdConfigPatches:" >> $(KIND_CONFIG_FILE) && \
		echo "- |-" >> $(KIND_CONFIG_FILE) && \
		echo '  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:$(REGISTRY_PORT)"]' >> $(KIND_CONFIG_FILE) && \
		echo '    endpoint = ["http://local-registry:5000"]' >> $(KIND_CONFIG_FILE) && \
		echo "nodes:" >> $(KIND_CONFIG_FILE) && \
		echo "- role: control-plane" >> $(KIND_CONFIG_FILE) && \
		echo "  kubeadmConfigPatches:" >> $(KIND_CONFIG_FILE) && \
		echo "  - |-" >> $(KIND_CONFIG_FILE) && \
		echo "    kind: InitConfiguration" >> $(KIND_CONFIG_FILE) && \
		echo "    nodeRegistration:" >> $(KIND_CONFIG_FILE) && \
		echo "      kubeletExtraArgs:" >> $(KIND_CONFIG_FILE) && \
		echo '        node-labels: "ingress-ready=true"' >> $(KIND_CONFIG_FILE) && \
		echo "  extraPortMappings:" >> $(KIND_CONFIG_FILE) && \
		echo "  - containerPort: 80" >> $(KIND_CONFIG_FILE) && \
		echo "    hostPort: 80" >> $(KIND_CONFIG_FILE) && \
		echo "    protocol: TCP" >> $(KIND_CONFIG_FILE) && \
		echo "  - containerPort: 443" >> $(KIND_CONFIG_FILE) && \
		echo "    hostPort: 443" >> $(KIND_CONFIG_FILE) && \
		echo "    protocol: TCP" >> $(KIND_CONFIG_FILE) && \
		echo "Kind configuration file generated successfully!"; \
	else \
		echo "Local registry is not running. Skipping Kind configuration generation."; \
	fi

# Add a new target to install NGINX Ingress Controller
kind_install_ingress:
	@echo "Installing NGINX Ingress Controller..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "Waiting for Ingress Controller to be ready..."
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s


# Create Kind cluster
kind_cluster_create: kind_install kubectl_install kind_config_generate
ifeq ($(KIND_CLUSTER_EXISTS),1)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' already exists"
	@kubectl get nodes
else
	@echo "Creating Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@kind create cluster --config=$(KIND_CONFIG_FILE)
	@$(MAKE) registry_connect
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' created successfully!"
	@kubectl get nodes
endif

# Clean up the generated Kind configuration file
kind_config_clean:
	@rm -f $(KIND_CONFIG_FILE)
	@echo "Kind configuration file cleaned up."

# Connect registry to Kind network (should happen after cluster creation)
registry_connect:
	@if [ ! -z "$$(docker network inspect kind 2>/dev/null)" ]; then \
		echo "Connecting registry to Kind network..."; \
		docker network connect kind $(REGISTRY_NAME) 2>/dev/null || true; \
		echo "Registry connected to Kind network!"; \
	else \
		echo "Kind network does not exist. Create a cluster first."; \
	fi

# Delete Kind cluster
kind_cluster_delete: kind_config_clean
ifeq ($(KIND_CLUSTER_EXISTS),1)
	@echo "Deleting Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' deleted successfully!"
else
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' does not exist"
endif

# Test registry with Kind cluster
registry_kind_test:
	@echo "Testing registry with Kind cluster..."
	@docker pull nginx:latest
	@docker tag nginx:latest localhost:$(REGISTRY_PORT)/nginx:latest
	@docker push localhost:$(REGISTRY_PORT)/nginx:latest
	@kubectl run nginx-test --image=localhost:$(REGISTRY_PORT)/nginx:latest
	@echo "Waiting for pod to start..."
	@kubectl wait --for=condition=ready pod/nginx-test --timeout=60s
	@echo "Test complete - nginx pod created successfully from local registry"

help:
	@echo "Available targets:"
	@echo "  run_website          - Build and run the website container"
	@echo "  stop_website         - Stop the running website container"
	@echo "  push_website         - Push website image to local registry"
	@echo "  status              - Check website container status"
	@echo "  install_kind        - Install Kind locally"
	@echo "  kind_config_generate         - Generate kind config for local registry"
	@echo "  kind_config_clean   - Clean up kind config files"
	@echo "  kind_cluster_create - Create a new Kind cluster"
	@echo "  kind_cluster_delete - Delete the Kind cluster"
	@echo "  registry_create     - Create local docker registry"
	@echo "  registry_delete     - Delete local docker registry"
	@echo "  registry_status     - Check registry status"
	@echo "  registry_test	     - Test local docker registry"
	@echo "  registry_kind_test  - Test kind cluster and docker local registry"
	@echo "  help                - Show this help message"
