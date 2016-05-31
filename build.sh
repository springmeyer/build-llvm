#!/usr/bin/env bash

set -e -u
set -o pipefail

PREFIX=${PREFIX:-"/opt/llvm/"}
JOBS=${JOBS:-8}
CWD=$(pwd)

# lldb has been frequently not compiling, so I've given up enabling it by default
# https://llvm.org/svn/llvm-project/lldb/trunk/docs/code-signing.txt
ENABLE_LLDB=false
USE_LATEST=false
LLVM_RELEASE=3.8.0

function abort { >&2 echo -e "\033[1m\033[31m$1\033[0m"; exit 1; }

function build_llvm() {
    # TODO - get this working or embed custom libc++
    #CLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/6.0/include:/usr/include
    #CPPLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/
    cd $CWD
    source_files=${CWD}/$1
    #rm -rf ./build
    mkdir -p ./build
    cd ./build
    # does not have cstdint
    #-DC_INCLUDE_DIRS=:/usr/include/c++/4.2.1/ \
    # fail
    # -DC_INCLUDE_DIRS=:../../../../../Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/ \
    # -DDEFAULT_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk \
    # NOTE: the C_INCLUDE_DIRS are appended to the DEFAULT_SYSROOT
    # the DEFAULT_SYSROOT should be:
    # Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk
    # but then it is hard to append and have found the C includes in /usr/include
    # and the C++ includes in /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/
    # so we fake the sysroot to be / to make it easy to append those specific paths
    cmake $source_files -G Ninja -DCMAKE_INSTALL_PREFIX=${PREFIX} \
     -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
     -DC_INCLUDE_DIRS=:/usr/include:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/ \
     -DDEFAULT_SYSROOT=/ \
     -DCMAKE_BUILD_TYPE=Release \
     -DLLVM_ENABLE_ASSERTIONS=Off \
     -DCLANG_VENDOR=mapbox/springmeyer \
     -DCLANG_REPOSITORY_STRING=https://github.com/springmeyer/build-llvm \
     -DCLANG_APPEND_VC_REV=$(git -C ../llvm/tools/clang/ rev-list --max-count=1 HEAD) \
     -DCLANG_VENDOR_UTI=org.mapbox.clang \
     -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
     -DCMAKE_CXX_FLAGS_RELEASE="${CXXFLAGS}" \
     -DLLVM_OPTIMIZED_TABLEGEN=ON
    ninja -j${JOBS} -k5
    ninja install -k5
    # manual install of tools that don't get installed right
    cp build/Release/bin/include-what-you-use ${PREFIX}/bin
}

function setup() {
    if [[ ! -d llvm ]]; then
        git clone --depth 1 http://llvm.org/git/llvm.git
        cd llvm/tools
        git clone --depth 1 http://llvm.org/git/clang.git
        if [[ ${ENABLE_LLDB} == true ]]; then
            git clone --depth 1 http://llvm.org/git/lldb.git
        fi
        cd clang/tools
        git clone --depth 1 http://llvm.org/git/clang-tools-extra.git extra
        git clone --depth 1 https://github.com/include-what-you-use/include-what-you-use.git
        cd ../../../
        cd ./projects
        git clone --depth 1 http://llvm.org/git/compiler-rt.git
        cd ../
    fi
}

function update() {
    echo "**** updating llvm"
    cd llvm
    GIT_PULL="git pull --rebase"
    if [[ ${ENABLE_LLDB} == true ]]; then
        (echo "**** updating lldb" && cd tools/lldb && ${GIT_PULL})
    fi
    (echo "**** updating clang" && cd tools/clang && ${GIT_PULL})
    (echo "**** updating clang-tools-extra" && cd tools/clang/tools/extra && ${GIT_PULL})
    (echo "**** updating include-what-you-use" && cd tools/clang/tools/include-what-you-use && ${GIT_PULL})
    (echo "**** updating compiler-rt" && cd projects/compiler-rt && ${GIT_PULL})
}

function setup_release() {
    mkdir -p llvm-${LLVM_RELEASE}
    cd llvm-${LLVM_RELEASE}
    wget "http://llvm.org/releases/${LLVM_RELEASE}/llvm-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/cfe-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/compiler-rt-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/libcxx-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/libcxxabi-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/libunwind-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/lld-${LLVM_RELEASE}.src.tar.xz"
    if [[ ${ENABLE_LLDB} == true ]]; then
        wget "http://llvm.org/releases/${LLVM_RELEASE}/lldb-${LLVM_RELEASE}.src.tar.xz"
    fi
    wget "http://llvm.org/releases/${LLVM_RELEASE}/openmp-${LLVM_RELEASE}.src.tar.xz"
    wget "http://llvm.org/releases/${LLVM_RELEASE}/clang-tools-extra-${LLVM_RELEASE}.src.tar.xz"
    for i in $(ls *.xz); do tar xf $i;done
    mv cfe-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/tools/clang
    mv compiler-rt-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/projects/compiler-rt
    mv libcxx-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/projects/libcxx
    mv libcxxabi-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/projects/libcxxabi
    mv libunwind-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/projects/libunwind
    mv lld-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/tools/lld
    if [[ ${ENABLE_LLDB} == true ]]; then
        mv lldb-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/tools/lldb
    fi
    mv openmp-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/projects/openmp
    mv clang-tools-extra-${LLVM_RELEASE}.src llvm-${LLVM_RELEASE}.src/tools/clang/tools/extra
    cd ../

}

function main() {
    which wget || abort 'please install wget'
    which git || abort 'please install git'
    which cmake || abort 'please install cmake'
    which ninja || abort 'please install ninja'
    if [[ -d ${PREFIX} ]]; then
        echo
        echo "Warning: installing over existing ${PREFIX}"
        echo
    fi
    export CXXFLAGS="-O3"
    export LDFLAGS=""
    # designed to limit the need for extra deps to build lldb
    if [[ ${ENABLE_LLDB} == true ]]; then
        export CXXFLAGS="-DLLDB_DISABLE_PYTHON -DLLDB_DISABLE_CURSES -DLLDB_DISABLE_LIBEDIT -DLLVM_ENABLE_TERMINFO=0 ${CXXFLAGS}"
    fi
    if [[ ${USE_LATEST} == true ]]; then
        if [[ ! -d llvm ]]; then
            setup
        else
            update
        fi
        build_llvm llvm
    else
        if [[ ! -d llvm-${LLVM_RELEASE} ]]; then
            setup_release
        fi
        build_llvm llvm-${LLVM_RELEASE}/llvm-${LLVM_RELEASE}.src
    fi
}

main