package containerd

import (
    "dagger.io/dagger"
    "dagger.io/dagger/core"
    gopkg "github.com/cpuguy83/docker-testing/pkg/go"
    "universe.dagger.io/docker"
    "universe.dagger.io/git"
)


#Build: {
    target: docker.#Image
    repo: "https://github.com/containerd/containerd.git"
    commit: string
    go: gopkg.#Go

    _path: "/go/src/github.com/containerd/containerd"

    _src: git.#Pull & {
        remote: repo,
        ref: commit,
        // runc build scripts use git to set commit id and version
        keepGitDir: true
    }


    _mounts: {
        "build-cache": gopkg.BuildCache
        "mod-cache": gopkg.ModCache
        "go": go.mount
    }

    build: docker.#Build & {
        steps: [
            docker.#Copy & {
                input: target,
                contents: _src.output
                dest: _path,
            },
            docker.#Run & {
                mounts: _mounts
                workdir: _path
                command: {
                    name: "/bin/sh"
                    args: ["-c", "PATH=/usr/local/go/bin:$PATH make binaries"]
                }
            }
        ]
    }

    _copy: core.#Copy & {
        input: dagger.#Scratch
        contents: build.output.rootfs
        source: "\(_path)/bin"
        dest: "/bin"
    }

    output: _copy.output
}