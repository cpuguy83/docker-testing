#!/usr/bin/env sh

set -e -o xtrace

: ${VERSION:=dev}
: ${OUTPUT:="$(pwd)/bin"}
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

go build -o "${OUTPUT}/dockerd" -tags "${BUILDTAGS}" -ldflags "${LDFLAGS}" -buildmode "${BUILDMODE}" ${EXTRA_BUILD_FLAGS} github.com/docker/docker/cmd/dockerd

(
	cd "${GOPATH}/src/github.com/docker/docker"
	export PREFIX="${OUTPUT}"
	hack/dockerfile/install/install.sh proxy
	hack/dockerfile/install/install.sh tini
)