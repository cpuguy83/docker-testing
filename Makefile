SHELL := /usr/bin/env bash -exo pipefail -c
.DEFAULT_GOAL := all

OUTPUT ?= out
export OUTPUT

export APT_MIRROR

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

$(OUTPUT)/$(DISTRO)/imageid: Dockerfile.$(DISTRO)
	mkdir -p $(dir $@)
	DOCKER_BUILDKIT=1 docker build $(_cache_from) --build-arg APT_MIRROR --iidfile="$(@)" -< ./Dockerfile.$(DISTRO)

export TEST_FILTER

test/env: $(OUTPUT)/$(DISTRO)/imageid
	[ -t 0 ] && withTty="--tty"; \
	docker run \
		--rm \
		-i \
		$${withTty} \
		--init \
		-e TEST_FILTER \
		--privileged \
		--mount type=bind,source=$(PWD)/$(OUTPUT)/frozen,target=/docker-frozen-images \
		--mount type=bind,source=$(PWD),target=/usr/local/docker-test \
		--tmpfs /usr/local/docker-test/out/tests/run \
		-v /var/lib/docker \
		--tmpfs /run \
		-w /usr/local/docker-test \
		"$$(cat $(<))" make test

test:
	artifacts_dir="$(shell pwd)/$(OUTPUT)"; \
	runDir="$${artifacts_dir}/tests/run"; \
	dataDir="$${artifacts_dir}/tests/data"; \
	trap 'jobs -p | xargs -r kill; wait; rm -rf "$${artifacts_dir}/tests/run"; rm -rf "$${artifacts_dir}/tests/data";' EXIT; \
	export PATH="$${artifacts_dir}/bin:$${PATH}"; \
	mkdir -p "$${runDir}"; \
	export DOCKER_HOST="unix://$${runDir}/docker.sock"; \
	dockerd -D --group="$$(id -g -n)" -H "$${DOCKER_HOST}"  > "$${artifacts_dir}/tests/docker.log" 2>&1 & \
	while true; do docker version && break; sleep 1; done; \
	docker info; \
	tar -cC "$${artifacts_dir}/frozen" . |  docker load; \
	cd "$${artifacts_dir}/src/github.com/docker/docker"; \
	mkdir -p "$${artifacts_dir}/emptyfs"; \
	DOCKER_HOST="$${DOCKER_HOST}" DEST="$${artifacts_dir}/emptyfs" sh hack/make/.ensure-emptyfs; \
	DOCKER_TEST_HOST="$${DOCKER_HOST}" \
	GOPATH="$${artifacts_dir}" \
	DOCKER_INTEGRATION_TESTS_VERIFIED=true \
	DOCKER_GITCOMMIT="NOBODYCARES" \
	DEST="${artifacts_dir}/test-integration" \
	hack/make.sh test-integration