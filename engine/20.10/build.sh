#!/usr/bin/env bash

set -e -o xtrace

export GO111MODULE=off

: ${VERSION:=20.10.7}

: ${GOPATH:=~/go}
TINI_COMMIT="$(. ${GOPATH}/src/github.com/docker/docker/hack/dockerfile/install/tini.installer; echo ${TINI_COMMIT})"

: ${GITCOMMIT:="$(git rev-parse HEAD || echo dev)"}

: ${BUILDTAGS:="journald apparmor seccomp"}
: ${IAMSTATIC:="false"}

GOOS="$(go env GOOS)"
GOARCH="$(go env GOARCH)"

if [ "$GOOS" = "windows" ]; then
	ext=".exe"
fi

: ${BUILDMODE:="pie"}
. hack/make/.go-autogen
go build -o "${OUTPUT}/bin/dockerd${ext}" -tags "${BUILDTAGS}" -ldflags "${LDFLAGS}" -buildmode "${BUILDMODE}" ${EXTRA_BUILD_FLAGS} github.com/docker/docker/cmd/dockerd

export PREFIX="${OUTPUT}/bin/"
hack/dockerfile/install/install.sh proxy
if [ "$GOOS" = "windows" ]; then
	mv "${PREFIX}/docker-proxy" "${PREFIX}/docker-proxy${ext}"
fi

if [ "$GOOS" = "linux" ]; then
	hack/dockerfile/install/install.sh tini
fi
TEST_FILTER=${TEST_FILTER} hack/make.sh build-integration-test-binary


if [ "$GOOS" = "linux" ]; then
	contrib/download-frozen-image-v2.sh "${OUTPUT}/frozen" \
		buildpack-deps:buster@sha256:d0abb4b1e5c664828b93e8b6ac84d10bce45ee469999bef88304be04a2709491 \
		busybox:latest@sha256:95cf004f559831017cdf4628aaf1bb30133677be8702a8c5f2994629f637a209 \
		busybox:glibc@sha256:1f81263701cddf6402afe9f33fca0266d9fff379e59b1748f33d3072da71ee85 \
		debian:bullseye@sha256:7190e972ab16aefea4d758ebe42a293f4e5c5be63595f4d03a5b9bf6839a4344 \
		hello-world:latest@sha256:d58e752213a51785838f9eed2b7a498ffa1cb3aa7f946dda11af39286c3db9a9 \
		arm32v7/hello-world:latest@sha256:50b8560ad574c779908da71f7ce370c0a2471c098d44d1c8f6b513c5a55eeeb1
fi

out="$(cd "${OUTPUT}" && pwd)"

mkdir -p "${GOPATH}/src/gotest.tools/gotestsum"
git clone --depth=1 https://github.com/gotestyourself/gotestsum "${GOPATH}/src/gotest.tools/gotestsum"
GO111MODULE=on go build -o "${out}/bin/gotestsum${ext}" gotest.tools/gotestsum

mkdir -p "${GOPATH}/src/github.com/docker/distribution"
cd "${GOPATH}/src/github.com/docker/distribution"
REGISTRY_COMMIT_SCHEMA1=ec87e9b6971d831f0eff752ddb54fb64693e51cd
REGISTRY_COMMIT=47a064d4195a9b56133891bbb13620c3ac83a827
git clone https://github.com/docker/distribution.git .
git checkout -q "$REGISTRY_COMMIT"
GOPATH="${GOPATH}/src/github.com/docker/distribution/Godeps/_workspace:$GOPATH"
	go build -buildmode=${BUILDMODE} -o "${out}/bin/registry-v2${ext}" github.com/docker/distribution/cmd/registry
git checkout -q "$REGISTRY_COMMIT_SCHEMA1"
GOPATH="${GOPATH}/src/github.com/docker/distribution/Godeps/_workspace:$GOPATH" \
	go build -buildmode=${BUILDMODE} -o "${out}/bin/registry-v2-schema1${ext}" github.com/docker/distribution/cmd/registry