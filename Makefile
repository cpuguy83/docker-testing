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

.PHONY: $(PROJECTS)
$(PROJECTS): # make (project name) VERSION=<project version> DISTRO=<distro>
	@if [ -z "$(VERSION)" ]; then \
		dirs=($(shell ls $(@))); \
		VERSION="$${dirs[-1]}"; \
	fi; \
	f="$(@)/$${VERSION}/Dockerfile.$(DISTRO)"; \
	docker buildx build --progress=$(PROGRESS) --output="$(OUTPUT)" -f "$${f}" "$(@)/$${VERSION}"

test-shell:
	docker run -it --rm -v /var/lib/docker --tmpfs /run -v /var/lib/containerd --privileged -v $(pwd):/opt/test -w /opt/test $(subst -,:,$(DISTRO))

# `make DISTRO=<name>` or just `make` for all distros
# Cannot set VERSION when calling this target
all: $(PROJECTS)

clean:
	rm -rf out