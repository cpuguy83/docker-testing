#!/usr/bin/env sh

set -e -o xtrace

: ${VERSION:=dev}
: ${OUTPUT:="$(pwd)"}
export OUTPUT

: ${GOPATH:=~/go}
TINI_COMMIT="$(. ${GOPATH}/src/github.com/docker/docker/hack/dockerfile/install/tini.installer; echo ${TINI_COMMIT})"

: ${BUILDTAGS:="journald apparmor seccomp"}
: ${LDFLAGS:=" \
	-X github.com/docker/docker/dockerversion.Version=${VERSION} \
	-X github.com/docker/docker/dockerversion.GitCommit=${GITCOMMIT} \
	-X github.com/docker/docker/dockerversion.BuildTime=${BUILDTIME} \
	-X github.com/docker/docker/dockerversion.IAmStatic=false \
	-X github.com/docker/docker/dockerversion.PlatformName=${PLATFORM} \
	-X github.com/docker/docker/dockerversion.ProductName=${PRODUCT} \
	-X github.com/docker/docker/dockerversion.DefaultProductLicense=${DEFAULT_PRODUCT_LICENSE} \
	-X github.com/docker/docker/dockerversion.InitCommitID=${TINI_COMMIT}
"}
: ${BUILDMODE:="pie"}

go build -o "${OUTPUT}/bin/dockerd" -tags "${BUILDTAGS}" -ldflags "${LDFLAGS}" -buildmode "${BUILDMODE}" ${EXTRA_BUILD_FLAGS} github.com/docker/docker/cmd/dockerd

export PREFIX="${OUTPUT}/bin/"
hack/dockerfile/install/install.sh proxy
hack/dockerfile/install/install.sh tini
hack/make.sh build-integration-test-binary
hack/dockerfile/install/install.sh gotestsum # Testing dependency
contrib/download-frozen-image-v2.sh "${OUTPUT}/frozen" \
	buildpack-deps:buster@sha256:d0abb4b1e5c664828b93e8b6ac84d10bce45ee469999bef88304be04a2709491 \
	busybox:latest@sha256:95cf004f559831017cdf4628aaf1bb30133677be8702a8c5f2994629f637a209 \
	busybox:glibc@sha256:1f81263701cddf6402afe9f33fca0266d9fff379e59b1748f33d3072da71ee85 \
	debian:bullseye@sha256:7190e972ab16aefea4d758ebe42a293f4e5c5be63595f4d03a5b9bf6839a4344 \
	hello-world:latest@sha256:d58e752213a51785838f9eed2b7a498ffa1cb3aa7f946dda11af39286c3db9a9 \
	arm32v7/hello-world:latest@sha256:50b8560ad574c779908da71f7ce370c0a2471c098d44d1c8f6b513c5a55eeeb1