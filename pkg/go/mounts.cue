package go

import (
    "dagger.io/dagger/core"
)

BuildCache: {
    contents: core.#CacheDir & {id: "go-build-cache"}
    dest: "/root/.cache/go-build"
}

ModCache: {
    contents: core.#CacheDir & {id: "go-mod-cache"}
    dest: "/go/pkg/mod"
}

