#!/usr/bin/env bash

set -e -u
set -o pipefail

export PATH=$(pwd)/mason_packages/.link/bin:${PATH}
export PATH=$(pwd)/ninja:${PATH}

MASON_VERSION="694d08c"

function setup_mason() {
    if [[ ! -d ./.mason ]]; then
        git clone https://github.com/mapbox/mason.git ./.mason
        (cd ./.mason && git checkout ${MASON_VERSION})
    else
        echo "Updating to latest mason"
        (cd ./.mason && git fetch && git checkout ${MASON_VERSION})
    fi
    export MASON_DIR=$(pwd)/.mason
    export PATH=$(pwd)/.mason:$PATH
}

setup_mason
mason install cmake 3.2.2
mason link cmake 3.2.2
if [[ ! -d ninja ]]; then
    git clone --depth=1 git://github.com/martine/ninja.git
    (cd ninja && ./configure.py --bootstrap)
fi

echo '#!/bin/bash' > ./cxx_compiler
echo 'ccache clang++ -Qunused-arguments "$@"' >> ./cxx_compiler
chmod +x ./cxx_compiler
export CXX="$(pwd)/cxx_compiler"
echo 'ccache clang -Qunused-arguments "$@"' >> ./c_compiler
chmod +x ./c_compiler
export CC="$(pwd)/c_compiler"
./build.sh
