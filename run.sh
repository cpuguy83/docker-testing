#!/usr/bin/env bash

set -e -u -x -o pipefail

cleanup() {
	set +e
	# Note this will try to unmount /go/src/github.com/docker/docker/bundles, which we are mounting below, and will get "target is busy", that's fine.
	mounts=("$(mount | grep '/go/src/github.com/docker/docker' | awk '{ print $3 }')")
	for i in ${mounts[@]}; do
		[ "${i}" = "/go/src/github.com/docker/docker/bundles" ] && continue
		umount -r -l "${i}"
	done

	for i in ${OUTDIR}/tests/test-integration/*; do
		[ -d "${i}" ] || continue
		find  "${i}" -maxdepth 3 -name root | xargs -I thefile rm -rf thefile
	done
	chown -R "${USER}:${GROUP}" "${OUTDIR}/tests"
}

trap "cleanup" EXIT


runTests() {
	rm -rf "${OUTDIR}/tests"
	mkdir -p "${OUTDIR}/tests"
	mkdir -p /go/src/github.com/docker/docker/bundles
	mount --bind "${OUTDIR}/tests" /go/src/github.com/docker/docker/bundles
	cd /go/src/github.com/docker/docker
	PATH="${OUTDIR}/bin:${PATH}" hack/make.sh test-integration
}

case "${1}" in
	clean)
		cleanup
		;;
	test)
		runTests
		;;
esac