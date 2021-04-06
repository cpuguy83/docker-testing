#!/usr/bin/env bash

set -e -u -o pipefail

: ${ENGINE_VERSION:=}
: ${CLI_VERSION:=}
: ${RUNC_VERSION:=}
: ${CONTAINERD_VERSION:=}

suite="${1}"
filter=".\"${suite}\""

if [ -n "${ENGINE_VERSION}" ]; then
	filter+=" | (..|.engine?) = [\"${ENGINE_VERSION}\"]"
fi
if [ -n "${CLI_VERSION}" ]; then
	filter+=" | (..|.cli?) = [\"${CLI_VERSION}\"]"
fi
if [ -n "${RUNC_VERSION}" ]; then
	filter+=" | (..|.runc?) = [\"${RUNC_VERSION}\"]"
fi
if [ -n "${CONTAINERD_VERSION}" ]; then
	filter+=" | (..|.containerd?) = [\"${CONTAINERD_VERSION}\"]"
fi
if [ -n "${OS_VERSION}" ]; then
	filter+=" | (..|.os?) = [\"${OS_VERSION}\"]"
fi

jq -c "${filter}" default-matrix.json