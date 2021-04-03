#!/usr/bin/env bash

set -e -u -x -o pipefail

trapHandler() {
	set +e
	for i in ${OUTDIR}/tests/test-integration/*; do
		[ -d "${i}" ] || continue
		find  "${i}" -maxdepth 2 -name root | tee | xargs rm -rf
	done
	chown -R "${USER}:${GROUP}" "${OUTDIR}/tests"
}

trap "trapHandler" EXIT

rm -rf "${OUTDIR}/tests"
mkdir -p "${OUTDIR}/tests"
mkdir -p /go/src/github.com/docker/docker/bundles
mount --bind "${OUTDIR}/tests" /go/src/github.com/docker/docker/bundles
cd /go/src/github.com/docker/docker
PATH="${OUTDIR}/bin:${PATH}" hack/make.sh test-integration