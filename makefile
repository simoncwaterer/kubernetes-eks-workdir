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


# Check if container is running
CONTAINER_RUNNING := $(shell docker ps --format '{{.Names}}' | grep -q '^$(CONTAINER_NAME)$$' && echo 1 || echo 0)

# Phony targets (targets that don't create files)
.PHONY: run_website stop_website status install_kind install_kubectl create_kind_cluster delete_kind_cluster

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

status:
ifeq ($(CONTAINER_RUNNING),1)
	@echo "Container '$(CONTAINER_NAME)' is running on port $(HOST_PORT)"
else
	@echo "Container '$(CONTAINER_NAME)' is not running"
endif

KIND_INSTALLED := $(shell which kind 2>/dev/null)

install_kind:
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

install_kubectl:
ifdef KUBECTL_INSTALLED
	@echo "Kubectl is already installed at: $(KIND_INSTALLED)"
	@kubectl version
else
	@echo "Installing kubectl with homebrew"
	@brew install kubectl
endif

# Check if cluster exists
KIND_CLUSTER_EXISTS := $(shell kind get clusters 2>/dev/null | grep -q '^$(KIND_CLUSTER_NAME)$$' && echo 1 || echo 0)

create_kind_cluster: install_kind install_kubectl
ifeq ($(KIND_CLUSTER_EXISTS),1)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' already exists"
else
	@echo "Creating Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@kind create cluster --name $(KIND_CLUSTER_NAME)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' created successfully!"
endif

delete_kind_cluster:
ifeq ($(KIND_CLUSTER_EXISTS),1)
	@echo "Deleting Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' deleted successfully!"
else
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' does not exist"
endif