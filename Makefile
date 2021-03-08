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
test:
	cd "$(PWD)/$(OUTPUT)/src/github.com/docker/docker"; \
	GOPATH="$(GOPATH)" \
	PATH="$(PWD)/$(OUTPUT)/bin:$${PATH}" \
	hack/make.sh test-integration