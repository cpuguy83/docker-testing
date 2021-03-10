SHELL := /usr/bin/env bash -exo pipefail -c
.DEFAULT_GOAL := all

OUTPUT ?= out
export OUTPUT

PROJECTS := engine runc containerd cli
PROGRESS := auto
ifeq ($(V), 1)
	PROGRESS := plain
endif

DISTRO ?= ubuntu-18.04

ifdef CACHE_FROM
_cache_from := --cache-from="$(CACHE_FROM)"
endif

ifdef CACHE_TO
_cache_to := --cache-to="$(CACHE_TO)"
endif

.PHONY: $(PROJECTS)
$(PROJECTS): # make (project name) VERSION=<project version> DISTRO=<distro>
	@if [ -z "$(VERSION)" ]; then \
		dirs=($(shell ls $(@))); \
		VERSION="$${dirs[-1]}"; \
	fi; \
	f="$(@)/$${VERSION}/Dockerfile.$(DISTRO)"; \
	docker buildx build $(_cache_from) $(_cache_to) --progress=$(PROGRESS) --output="$(OUTPUT)" -f "$${f}" "$(@)/$${VERSION}"

test-shell:
	docker run -it --rm -v /var/lib/docker --tmpfs /run -v /var/lib/containerd --privileged -v $(pwd):/opt/test -w /opt/test $(subst -,:,$(DISTRO))

# `make DISTRO=<name>` or just `make` for all distros
# Cannot set VERSION when calling this target
all: $(PROJECTS)

clean:
	rm -rf out

test: GOPATH := $(PWD)/$(OUTPUT)
test: DOCKER_INTEGRATION_TESTS_VERIFIED = true
test: ARTIFACTS_DIR := $(PWD)/$(OUTPUT)
test:
	runDir="$(ARTIFACTS_DIR)/tests/run"; \
	dataDir="$(ARTIFACTS_DIR)/tests/data"; \
	trap 'jobs -p | sudo xargs -r kill; wait; rm -rf "$(ARTIFACTS_DIR)/tests/run"; rm -rf "$(ARTIFACTS_DIR)/tests/data";' EXIT; \
	ls -lh "$(ARTIFACTS_DIR)/"; \
	ls -lh "$(ARTIFACTS_DIR)/bin"; \
	export PATH="$(ARTIFACTS_DIR)/bin:$${PATH}"; \
	mkdir -p "$${runDir}"; \
	export DOCKER_HOST="unix://$${runDir}/docker.sock"; \
	sudo PATH="$${PATH}" dockerd -D --group="$$(id -g -n)" -H "$${DOCKER_HOST}" --exec-root="${runDir}/exec" --data-root="$${dataDir}" > "$(ARTIFACTS_DIR)/docker.log" 2>&1 & \
	while true; do docker version && break; sleep 1; done; \
	docker info; \
	tar -cC "$(ARTIFACTS_DIR)/frozen" . |  docker load; \
	cd "$(ARTIFACTS_DIR)/src/github.com/docker/docker"; \
	mkdir -p "$(ARTIFACTS_DIR)/emptyfs"; \
	DOCKER_HOST="$${DOCKER_HOST}" DEST="$(ARTIFACTS_DIR)/emptyfs" sh hack/make/.ensure-emptyfs; \
	DOCKER_TEST_HOST="$${DOCKER_HOST}" \
	GOPATH="$(GOPATH)" \
	hack/make.sh test-integration