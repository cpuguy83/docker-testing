package ubuntu

import (
    "strings"

    "dagger.io/dagger/core"
    "dagger.io/dagger"
    "universe.dagger.io/docker"
)



#Build: {
    version: string

    _keep_cache: core.#WriteFile & {
        input: dagger.#Scratch
        contents: "Binary::apt::APT::Keep-Downloaded-Packages \"true\";"
        path: "/keep-cache"
    }

    _packages: strings.Join(_images._packages[version], " ")

    _build: docker.#Build & {
        steps: [
            docker.#Pull & {
                source: strings.Replace(version, "-", ":", 1),
            },
            docker.#Copy & {
                contents: _keep_cache.output
                dest: "/etc/apt/apt/conf.d/keep-cache"
            },
            docker.#Run & {
                mounts: {
                    "apt-cache": {
                        contents: core.#CacheDir & {
                            concurrency: "locked"
                            id: "\(version)-apt-cache"
                        }
                        dest: "/var/cache/apt"
                    },
                    "apt-lib": {
                        contents: core.#CacheDir & {
                            concurrency: "locked"
                            id: "\(version)-apt-lib"
                        }
                        dest: "/var/lib/apt"
                    },
                }
                env: {
                    DEBIAN_FRONTEND: "noninteractive"
                    PACKAGES: _packages
                }
                command: {
                    name: "/bin/sh",
                    args: ["-c", "echo Installing $PACKAGES; apt-get update && apt-get install -y $PACKAGES"]
                }
            }
        ]
    }

    output: _build.output
}


_images: {
    _packages: {
        "ubuntu-18.04": [
            "btrfs-tools",
            "cmake",
            "gcc",
            "git",
            "dh-apparmor",
            "dh-exec",
            "jq",
            "make",
            "pkg-config",
            "libapparmor-dev",
            "libdevmapper-dev",
            "libltdl-dev",
            "libseccomp-dev",
            "libsystemd-dev",
        ]

        "ubuntu-20.04": [
            "cmake",
            "gcc",
            "git",
            "dh-apparmor",
            "dh-exec",
            "jq",
            "make",
            "pkg-config",
            "libapparmor-dev",
            "libbtrfs-dev",
            "libdevmapper-dev",
            "libltdl-dev",
            "libseccomp-dev",
            "libsystemd-dev",
        ]

        "ubuntu-22.04": _packages["ubuntu-20.04"]
    }
}