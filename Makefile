SHELL := /usr/bin/env bash -exo pipefail -c
.DEFAULT_GOAL := all

OUTPUT ?= bin
export OUTPUT

PROJECTS := engine runc
PROGRESS := auto
ifeq ($(V), 1)
	PROGRESS := plain
endif

.PHONY: $(PROJECTS)
$(PROJECTS): # make (project name) VERSION=<project version> DISTRO=<distro>
	@if [ -z $(VERSION) ]; then \
		dirs=($(shell ls $(@))); \
		VERSION="$${dirs[-1]}"; \
	fi; \
	if [ -z $(DISTRO) ]; then \
		ls=($$(ls $(@)/$${VERSION}/Dockerfile.*)); \
		f="$${ls[-1]}"; \
		fileName="$${f##*/}"; \
		distro=$${fileName#*.}; \
		out="$(OUTPUT)/$(@)/$${VERSION}/$${distro}/"; \
	else \
		f="$(@)/$${VERSION}/Dockerfile.$(DISTRO)"; \
		out="$(OUTPUT)/$(@)/$${VERSION}/$(DISTRO)"; \
	fi; \
	docker buildx build --progress=$(PROGRESS) --output="$${out}" -f "$${f}" "$(@)/$${VERSION}"


# `make DISTRO=<name>` or just `make` for all distros
# Cannot set VERSION when calling this target
all: $(PROJECTS)