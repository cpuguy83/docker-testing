package main

import (
    "dagger.io/dagger"
    "dagger.io/dagger/core"

    "github.com/cpuguy83/docker-testing/pkg/ubuntu"
    "github.com/cpuguy83/docker-testing/cli"
    "github.com/cpuguy83/docker-testing/containerd"
    "github.com/cpuguy83/docker-testing/engine"
    "github.com/cpuguy83/docker-testing/runc"
    "github.com/cpuguy83/docker-testing/pkg/go"
)



dagger.#Plan & {
    client: {
        filesystem: {
            "./out": write: contents: actions.build.output
            "./engine": read: contents: dagger.#FS
        }
        env: {
            GO_VERSION: string | *"1.17"
            DISTRO: string | *"ubuntu-18.04"

            CLI_COMMIT: string | *"v20.10.14"
            CONTAINERD_COMMIT: string | *"v1.6.2"
            ENGINE_COMMIT: string | *"v20.10.14"
            RUNC_COMMIT: string | *"v1.0.3"
        }
    }

    actions: {
        _target: ubuntu.#Build & { version: client.env.DISTRO }
        _go: go.#Go & { version: client.env.GO_VERSION }

        _cli: cli.#Build & {
            target: _target.output
            commit: client.env.CLI_COMMIT
            "go": _go
        }

        _containerd: containerd.#Build & {
            target: _target.output
            commit: client.env.CONTAINERD_COMMIT
            "go": _go
        }

        _engine: engine.#Build & {
            input: client.filesystem."./engine".read.contents
            target: _target.output
            commit: client.env.ENGINE_COMMIT
            "go": _go
        }

        _runc: runc.#Build & {
            target: _target.output
            commit: client.env.RUNC_COMMIT
            "go": _go
        }

        build: core.#Merge & {
            inputs: [
                _cli.output,
                _containerd.output,
                _runc.output,
                _engine.output,
            ]
        }
    }
}