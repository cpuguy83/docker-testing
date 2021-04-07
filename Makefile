SHELL := /usr/bin/env bash -exo pipefail -c
.DEFAULT_GOAL := all

export OUTPUT := out

export APT_MIRROR
export TEST_FILTER

ifdef TESTFLAGS
export TESTFLAGS
endif

ifdef TEST_SKIP_INTEGRATION_CLI
export TEST_SKIP_INTEGRATION_CLI
endif

ifdef TEST_SKIP_INTEGRATION
export TEST_SKIP_INTEGRATION
endif

PROJECTS := engine runc containerd cli
PROGRESS := auto
ifeq ($(V), 1)
	PROGRESS := plain
endif

DISTRO ?= ubuntu-18.04

ifndef NO_OUTPUT
_output := --output="$(OUTPUT)"
endif

# Used by the $(PROJECTS) target to get the value of a project specific var, e.g. RUNC_VERSION
#
# Use: `$(call project_var_val,VERSION)` to get the value of the var <MAKETARGET>_VERSION
project_var_val = $($(call project_var,$(1)))
project_var = $(shell echo '$@' |  tr '[:lower:]' '[:upper:]')_$(1)

# function calls to get cache from/to lines for docker build
_cache_from = $(shell \
	if [ -n "$(CACHE_FROM)" ]; then \
		echo --cache-from $(CACHE_FROM); \
		exit 0; \
	fi; \
	_tmp_cache_from="$(call project_var_val,CACHE_FROM)"; \
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
	_tmp_cache_to="$(call project_var_val,CACHE_TO)"; \
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
	_tmp_version=$(call project_var_val,VERSION); \
	if [ -n "$${_tmp_version}" ]; then \
		echo "$${_tmp_version}"; \
		exit 0; \
	fi; \
	dirs=($$(ls $(@))); \
	echo $${dirs[-1]}; \
)

BUILD_ARGS := \
	--build-arg APT_MIRROR

engine: BUILD_ARGS += --build-arg TEST_FILTER

.PHONY: $(PROJECTS)
$(PROJECTS): BUILD_ARGS += --build-arg $(call project_var,COMMIT) --build-arg $(call project_var,REPO)
$(PROJECTS): # make (project name) VERSION=<project version> DISTRO=<distro>, prefix (non-DISTRO) variables with the project name you are setting if you want to build multiple at once
	VERSION="$(call get_version)"; \
	f="$(@)/$${VERSION}/Dockerfile.$(DISTRO)"; \
	docker buildx build $(call _cache_from) $(call _cache_to) $(BUILD_ARGS) --progress=$(PROGRESS) $(_output) -f "$${f}" "$(@)/$${VERSION}"

test-shell:
	docker run -it --rm -v /var/lib/docker --tmpfs /run -v /var/lib/containerd --privileged -v $(pwd):/opt/test -w /opt/test $(subst -,:,$(DISTRO))

# `make DISTRO=<name>` or just `make` for all distros
# Cannot set VERSION when calling this target
all: $(PROJECTS) test

clean:
	rm -rf out

$(OUTPUT)/$(DISTRO)/imageid: Dockerfile.$(DISTRO)
	mkdir -p $(dir $@); \
	DOCKER_BUILDKIT=1 docker build $(_cache_from) --build-arg APT_MIRROR --iidfile="$(@)" -< ./Dockerfile.$(DISTRO)

ifdef DOCKER_INTEGRATION_TESTS_VERIFIED
export DOCKER_INTEGRATION_TESTS_VERIFIED
endif

test: $(OUTPUT)/$(DISTRO)/imageid
	[ -t 0 ] && withTty="--tty"; \
	docker run \
		--rm \
		-i \
		$${withTty} \
		--init \
		-e TEST_FILTER \
		-e TESTFLAGS \
		-e TEST_SKIP_INTEGRATION_CLI \
		-e TEST_SKIP_INTEGRATION \
		-e GOCACHE="$(PWD)/$(OUTPUT)/gobuildcache" \
		-e DOCKER_GITCOMMIT="NOBODYCARES" \
		-e DOCKER_INTEGRATION_TESTS_VERIFIED \
		-e GOPATH=/go \
		-e DOCKER_GRAPHDRIVER \
		-e USER="$(shell id -u)" \
		-e GROUP="$(shell id -g)" \
		-e OUTDIR="$(PWD)/$(OUTPUT)" \
		-e TIMEOUT \
		--privileged \
		-v /var/lib/docker \
		--tmpfs /run \
		--mount "type=bind,source=$(PWD)/$(OUTPUT)/frozen,target=/docker-frozen-images" \
		--mount "type=bind,source=$(PWD),target=$(PWD)" \
		--mount "type=bind,source=$(PWD)/$(OUTPUT)/src,target=/go/src" \
		-w "$(PWD)" \
		"$$(cat $(<))" "$(PWD)/run.sh" test