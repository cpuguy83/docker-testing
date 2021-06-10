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
if [[ "$suite" =~ "windows" ]]; then
	if [ -n "${OS_VERSION_WINDOWS}" ]; then
		filter+=" | (..|.os?) = [\"${OS_VERSION_WINDOWS}\"]"
	fi
else
	if [ -n "${OS_VERSION_LINUX}" ]; then
		filter+=" | (..|.os?) = [\"${OS_VERSION_LINUX}\"]"
	fi
fi

jq -c "${filter}" default-matrix.json