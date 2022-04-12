package go

import (
    "dagger.io/dagger/core"
    "universe.dagger.io/docker"
)

#Go: {
    version: string

    _pull: docker.#Pull & {
        source: "golang:\(version)"
    }

    _subdir: core.#Subdir & {
        input: _pull.output.rootfs
        path: "/usr/local/go"
    }

    output: _subdir.output

    mount: {
        type: "fs"
        dest: "/usr/local/go"
        source: "/usr/local/go"
        contents: _pull.output.rootfs
        ro: true
    }
}