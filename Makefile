SHELL := /usr/bin/env bash -exo pipefail -c
.DEFAULT_GOAL := all

export OUTPUT := out

export APT_MIRROR
export TEST_FILTER

PROJECTS := engine runc containerd cli
PROGRESS := auto
ifeq ($(V), 1)
	PROGRESS := plain
endif

DISTRO ?= ubuntu-18.04

ifndef NO_OUTPUT
_output := --output="$(OUTPUT)"
endif

# functions used to get the correctly cased variable names that are referenced
PROJECT_VERSION = $(shell echo '$@' |  tr '[:lower:]' '[:upper:]')_VERSION
PROJECT_CACHE_FROM = $(shell echo '$@' |  tr '[:lower:]' '[:upper:]')_CACHE_FROM
PROJECT_CACHE_TO = $(shell echo '$@' |  tr '[:lower:]' '[:upper:]')_CACHE_TO

# function calls to get cache from/to lines for docker build
_cache_from = $(shell \
	if [ -n "$(CACHE_FROM)" ]; then \
		echo --cache-from $(CACHE_FROM); \
		exit 0; \
	fi; \
	_tmp_cache_from="$($(call PROJECT_CACHE_FROM))"; \
	if [ -n "$${_tmp_cache_from}" ]; then \
		echo --cache-from $${_tmp_cache_from}; \
		exit 0; \
	fi; \
)
_cache_to = $(shell \
	if [ -n "$(CACHE_TO)" ]; then \
		echo --cache-to $(CACHE_TO); \
		exit 0; \
	fi; \
	_tmp_cache_to="$($(call PROJECT_CACHE_TO))"; \
	if [ -n "$${_tmp_cache_to}" ]; then \
		echo --cache-to $${_tmp_cache_to}; \
		exit 0; \
	fi; \
)

# function call to determine what version to build against
get_version = $(shell \
	if [ -n "$(VERSION)" ]; then \
		echo $(VERSION); \
		exit 0; \
	fi; \
	if [ -n "$($(call PROJECT_VERSION))" ]; then \
		echo $($(call PROJECT_VERSION)); \
		exit 0; \
	fi; \
	dirs=($$(ls $(@))); \
	echo $${dirs[-1]}; \
)

.PHONY: $(PROJECTS)
$(PROJECTS): # make (project name) VERSION=<project version> DISTRO=<distro>
	VERSION="$(call get_version)"; \
	f="$(@)/$${VERSION}/Dockerfile.$(DISTRO)"; \
	docker buildx build $(call _cache_from) $(call _cache_to) --progress=$(PROGRESS) --build-arg TEST_FILTER $(_output) -f "$${f}" "$(@)/$${VERSION}"

test-shell:
	docker run -it --rm -v /var/lib/docker --tmpfs /run -v /var/lib/containerd --privileged -v $(pwd):/opt/test -w /opt/test $(subst -,:,$(DISTRO))

# `make DISTRO=<name>` or just `make` for all distros
# Cannot set VERSION when calling this target
all: $(PROJECTS) test

clean:
	rm -rf out

$(OUTPUT)/$(DISTRO)/imageid: Dockerfile.$(DISTRO)
	mkdir -p $(dir $@)
	DOCKER_BUILDKIT=1 docker build $(_cache_from) --build-arg APT_MIRROR --iidfile="$(@)" -< ./Dockerfile.$(DISTRO)

export TEST_FILTER

$(OUTPUT)/bin/docker: cli
$(OUTPUT)/bin/dockerd: engine
$(OUTPUT)/src/github.com/docker/docker: engine

$(OUTPUT)/bin/containerd: containerd
$(OUTPUT)/bin/runc: runc

test: $(OUTPUT)/$(DISTRO)/imageid
	[ -t 0 ] && withTty="--tty"; \
	docker run \
		--rm \
		-i \
		$${withTty} \
		--init \
		-e TEST_FILTER \
		-e GOCACHE="$(PWD)/$(OUTPUT)/gobuildcache" \
		-e DOCKER_GITCOMMIT="NOBODYCARES" \
		-e GOPATH=/go \
		-e DOCKER_INTEGRATION_TESTS_VERIFIED=true \
		--privileged \
		--mount "type=bind,source=$(PWD)/$(OUTPUT)/frozen,target=/docker-frozen-images" \
		--mount "type=bind,source=$(PWD),target=$(PWD),ro" \
		--mount "type=bind,source=$(PWD)/$(OUTPUT),target=$(PWD)/$(OUTPUT)" \
		--mount "type=bind,source=$(PWD)/$(OUTPUT)/src,target=/go/src" \
		-w "$(PWD)" \
		"$$(cat $(<))" sh -xec '\
			trap "chown -R $(shell id -u):$(shell id -g) $(PWD)/$(OUTPUT)" EXIT; \
			rm -rf $(PWD)/$(OUTPUT)/tests; \
			mkdir -p $(PWD)/$(OUTPUT)/tests; \
			mkdir -p /go/src/github.com/docker/docker/bundles; \
			mount --bind $(PWD)/$(OUTPUT)/tests /go/src/github.com/docker/docker/bundles; \
			cd /go/src/github.com/docker/docker; \
			PATH="$(PWD)/$(OUTPUT)/bin:$${PATH}" hack/make.sh test-integration; \
		'