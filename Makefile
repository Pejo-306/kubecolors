# Phony targets (grouped to match `make help` sections)
.PHONY: help
.PHONY: build push
.PHONY: namespace secrets up down
.PHONY: infra-init infra-diff infra-apply infra-show infra-destroy
.PHONY: smoke-test metrics flush load-data load-test

.DEFAULT_GOAL := up

# Build variables
BUILD_VERSION := 2.0.1
BUILD_TAG := penikolov23/color-api:${BUILD_VERSION}

# Project directories and files
SRC_DIR := color-api
SCRIPTS_DIR := scripts
KUBERNETES_DIR := kubernetes
TERRAFORM_DIR := ${KUBERNETES_DIR}/cluster
SOPS_AGE_KEY_FILE := keys.txt

# Kustomize overlays
OVERLAY ?= docker-desktop
OVERLAY_DIR := ${KUBERNETES_DIR}/overlay/${OVERLAY}
NAMESPACE_FILE := $(wildcard ${OVERLAY_DIR}/*namespace*.yaml)

# Test variables
KUBECOLORS_ENDPOINT ?=
CONCURRENT_REQUESTS := 10
RECORDS := 100
UPDATES := 50
GETS := 200
KEY_LENGTH := 6

# Kubernetes and Docker tasks for kubecolors project. Use `make help` to see available targets.

help:
	@echo "Targets to build, deploy, and operate the kubecolors project:"
	@echo ""
	@echo "\033[1mDOCKER:\033[0m"
	@echo "    build                              - Build color-api Docker image"
	@echo "    push                               - Push color-api image to registry"
	@echo ""
	@echo "  Environment variables:"
	@echo "    ├── BUILD_VERSION                  - Version of the color-api image (default: 2.0.1)"
	@echo "    └── BUILD_TAG                      - Tag of the color-api image (default: penikolov23/color-api:${BUILD_VERSION})"
	@echo ""
	@echo "\033[1mKUBERNETES DEPLOYMENT:\033[0m"
	@echo "    namespace                          - Apply the overlay Namespace manifest"
	@echo "    secrets                            - Decrypt and apply secrets for current OVERLAY"
	@echo "    up                                 - namespace, secrets, then kustomize apply (DB + API)"
	@echo "    down                               - Delete the overlay namespace (wipes all resources in it)"
	@echo ""
	@echo "\033[1mGCP INFRASTRUCTURE:\033[0m"
	@echo "    infra-init                         - Download Terraform providers (run once)"
	@echo "    infra-diff                         - Show planned infrastructure changes"
	@echo "    infra-apply                        - Create or update GCP infrastructure (terraform apply)"
	@echo "    infra-show                         - Show Terraform outputs (static IPs, cluster name, etc.)"
	@echo "    infra-destroy                      - Destroy all GCP infrastructure (terraform destroy)"
	@echo ""
	@echo "\033[1mTESTING & OPERATIONS:\033[0m"
	@echo "    smoke-test                         - Run smoke tests against endpoint"
	@echo "    metrics                            - Fetch Prometheus /metrics from the API"
	@echo "    flush                              - Flush data at endpoint"
	@echo "    load-data                          - Load sample data (RECORDS=200, KEY_LENGTH=6)"
	@echo "    load-test                          - Run load test (CONCURRENT_REQUESTS=10, RECORDS=100, UPDATES=50, GETS=200)"
	@echo ""
	@echo "  Environment variables:"
	@echo "    ├── KUBECOLORS_ENDPOINT            - Endpoint of the color-api service (required)."
	@echo "    │                                    You can retrieve the endpoint by inspecting the"
	@echo "    │                                    exposed NodePort endpoint of the 'color-api' service."
	@echo "    ├── CONCURRENT_REQUESTS            - Number of concurrent requests (default: 10)"
	@echo "    ├── RECORDS                        - Number of records to load (default: 100)"
	@echo "    ├── UPDATES                        - Number of updates to perform (default: 50)"
	@echo "    ├── GETS                           - Number of gets to perform (default: 200)"
	@echo "    └── KEY_LENGTH                     - Length of the key to use (default: 6)"
	@echo ""
	@echo "  Kubernetes:"
	@echo "    └── OVERLAY                        - Kustomize overlay name (default: docker-desktop)."
	@echo "                                         Use dev or prod for kubecolors-dev / kubecolors-prod."
	@echo ""
	@echo "\033[1mUSAGE EXAMPLES:\033[0m"
	@echo "  make up"
	@echo "  make up OVERLAY=dev"
	@echo "  make smoke-test KUBECOLORS_ENDPOINT=http://localhost:8080"
	@echo "  make metrics KUBECOLORS_ENDPOINT=http://localhost:8080"
	@echo "  make load-data RECORDS=500 KEY_LENGTH=8"
	@echo ""
	@echo "\033[1mLOAD TESTING:\033[0m"
	@echo "  make load-test"
	@echo "  make load-test CONCURRENT_REQUESTS=100 RECORDS=1000 UPDATES=2000 GETS=10000  # heavy load test"

# Docker build and push targets
# -----------------------------
# You can change the build tag to your own registry and image name. Or deploy
# the kubernetes resources with my `penikolov23/color-api:2.0.1` image.

build:
	docker build -t ${BUILD_TAG} ${SRC_DIR}

push:
	docker push ${BUILD_TAG}

# Kubernetes deployment targets
# -----------------------------

namespace:
	kubectl apply -f $(NAMESPACE_FILE)

secrets:
	@find ${OVERLAY_DIR}/secrets/ -name '*.yaml' -exec sh -c \
		'SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE} sops --decrypt "$$1" | kubectl apply -f -' _ {} \;

up: namespace secrets
	kustomize build ${OVERLAY_DIR} | kubectl apply -f -

down:
	kubectl delete namespace $$(grep -E '^namespace:[[:space:]]' ${OVERLAY_DIR}/kustomization.yaml | head -1 | awk '{print $$2}') --ignore-not-found

# GCP infrastructure (Terraform)
# ------------------------------

infra-init:
	terraform -chdir=${TERRAFORM_DIR} init

infra-diff:
	terraform -chdir=${TERRAFORM_DIR} plan

infra-apply:
	terraform -chdir=${TERRAFORM_DIR} apply

infra-show:
	terraform -chdir=${TERRAFORM_DIR} output

infra-destroy:
	terraform -chdir=${TERRAFORM_DIR} destroy

# Tests and operations targets
# -----------------------------
# All of these targets rely on:
#   - KUBECOLORS_ENDPOINT being set to the NodePort endpoint of the `color-api` service
#   - `color-api` service is deployed and running

smoke-test:
	@if [ -z "${KUBECOLORS_ENDPOINT}" ]; then echo "Error: KUBECOLORS_ENDPOINT is required"; exit 1; fi
	@bash ${SCRIPTS_DIR}/smoke-test.sh --endpoint ${KUBECOLORS_ENDPOINT}

metrics:
	@if [ -z "${KUBECOLORS_ENDPOINT}" ]; then echo "Error: KUBECOLORS_ENDPOINT is required"; exit 1; fi
	@SCRIPTS_DIR='${SCRIPTS_DIR}' KUBECOLORS_ENDPOINT='${KUBECOLORS_ENDPOINT}' bash -euo pipefail -c '\
		source "$$SCRIPTS_DIR/kubecolors-base-url.sh" && \
		curl -sS "$$(kubecolors_normalized_base_url "$$KUBECOLORS_ENDPOINT")/metrics"'

load-data:
	@if [ -z "${KUBECOLORS_ENDPOINT}" ]; then echo "Error: KUBECOLORS_ENDPOINT is required"; exit 1; fi
	@bash ${SCRIPTS_DIR}/load.sh \
		--endpoint ${KUBECOLORS_ENDPOINT} \
		-n ${RECORDS} \
		-l ${KEY_LENGTH}

flush:
	@if [ -z "${KUBECOLORS_ENDPOINT}" ]; then echo "Error: KUBECOLORS_ENDPOINT is required"; exit 1; fi
	@bash ${SCRIPTS_DIR}/flush.sh --endpoint ${KUBECOLORS_ENDPOINT}

load-test:
	@if [ -z "${KUBECOLORS_ENDPOINT}" ]; then echo "Error: KUBECOLORS_ENDPOINT is required"; exit 1; fi
	@bash ${SCRIPTS_DIR}/load-test.sh \
		--endpoint ${KUBECOLORS_ENDPOINT} \
		--concurrent-requests ${CONCURRENT_REQUESTS} \
		-n ${RECORDS} \
		-u ${UPDATES} \
		--gets ${GETS}
