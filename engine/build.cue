package engine


import (
    "strings"

    "dagger.io/dagger"
    "dagger.io/dagger/core"
    gopkg "github.com/cpuguy83/docker-testing/pkg/go"
    "universe.dagger.io/docker"
    "universe.dagger.io/git"
)


#Build: {
    input: dagger.#FS
    target: docker.#Image
    repo: "https://github.com/moby/moby.git"
    commit: string
    go: gopkg.#Go

    _path: "/go/src/github.com/docker/docker"

    _src: git.#Pull & {
        remote: repo,
        ref: commit,
        keepGitDir: true
    }

    _mounts: {
        "build-cache": gopkg.BuildCache
        "mod-cache": gopkg.ModCache
        "go": go.mount
        "build.sh":  {
            type: "fs",
            dest: "/tmp/build.sh"
            contents: input
            source: "\(_branch_trimmed)/build.sh"
            ro: true
        }
    }

    _do_branch: docker.#Run & {
        "input": target,
        workdir: _path,
        mounts:  {
            "src": {
                type: "fs"
                dest: _path
                contents: _src.output
            }
        }
        env: COMMIT: commit
        command: {
            name: "bash"
            args: ["-xc", """
                git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
                git fetch --unshallow
                git branch --contains $COMMIT --format='%(refname:short)' -a | grep -v 'no branch' | head -n 1 | awk -F'/' '{ print $2 }' | tee /tmp/BRANCH
            """]
        }
    }

    _branch: core.#ReadFile & {
        input: _do_branch.output.rootfs
        path: "/tmp/BRANCH"
    }

    _branch_trimmed: strings.TrimPrefix(strings.TrimSpace(_branch.contents), "v")

    build: docker.#Build & {
        steps: [
            docker.#Copy & {
                input: target
                contents: _src.output
                dest: _path
            },
            docker.#Run & {
                mounts: _mounts
                workdir: _path
                env: {
                    GOPATH: "/go"
                    GO111MODULE: "off"
                    OUTPUT: "/tmp/out"
                }
                command: {
                    name: "/bin/sh"
                    args: ["-c", "PATH=/usr/local/go/bin:$PATH /tmp/build.sh"]
                }
            }
        ]
    }


    _bins: core.#Copy & {
        input: dagger.#Scratch
        contents: build.output.rootfs
        source: "/tmp/out"
        dest: "/"
    }

    _merge: core.#Copy & {
        input: _bins.output
        contents: build.output.rootfs
        source: "/go/src/github.com/docker/docker"
        dest: "/src/github.com/docker/docker"
    }


    output: _merge.output
}