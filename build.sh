#!/usr/bin/env bash

set -e -u
set -o pipefail

PREFIX=${PREFIX:-"/opt/llvm/"}
JOBS=${JOBS:-4}
CWD=$(pwd)

function abort { >&2 echo -e "\033[1m\033[31m$1\033[0m"; exit 0; }


function build() {
    # TODO - get this working or embed custom libc++
    #CLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/6.0/include:/usr/include
    #CPPLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/
    #  --with-c-include-dirs=${CLIB}:${CPPLIB}
    OPTS=""
    if [[ $(uname -s) == 'Darwin' ]]; then
        OPTS="--enable-libcpp --enable-cxx11"
    fi
    cd $CWD
    rm -rf ./build
    mkdir ./build
    cd ./build
    ../llvm/configure --prefix=${PREFIX} --enable-optimized --enable-clang-static-analyzer --disable-assertions $OPTS
    time make ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 -j${JOBS}
    make install ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 -j${JOBS}
    cp Release/bin/clang "${PREFIX}/bin/clang"
    strip -x ${PREFIX}/bin/clang

}

function setup() {
    if [[ ! -d llvm ]]; then
        git clone --depth 1 http://llvm.org/git/llvm.git
        cd llvm/tools
        git clone --depth 1 http://llvm.org/git/clang.git
        # c-index-test build is broken against libxml2
        perl -p -i -e 's/c-index-test//g' clang/tools/Makefile
        #git clone --depth 1 http://llvm.org/git/lldb.git
        cd clang/tools
        git clone --depth 1 http://llvm.org/git/clang-tools-extra.git extra
        svn co http://include-what-you-use.googlecode.com/svn/trunk/ include-what-you-use
        perl -p -i -e 's/diagtool/diagtool include-what-you-use/g' Makefile
        cd ../../../
        cd ./projects
        git clone --depth 1 http://llvm.org/git/compiler-rt.git
        cd ../
        git config branch.master.rebase true
    fi
}

function update() {
    CLEAN=""
    echo "**** updating llvm"
    cd llvm
    ${CLEAN} && git pull
    #(echo "**** updating lldb" && cd tools/lldb && ${CLEAN} && git pull)
    (echo "**** updating clang" && cd tools/clang && ${CLEAN} && git pull)
    (echo "**** updating clang-tools-extra" && cd tools/clang/tools/extra && ${CLEAN} && git pull)
    (echo "**** updating include-what-you-use" && cd tools/clang/tools/include-what-you-use && ${CLEAN} && svn up)
    (echo "**** updating compiler-rt" && cd projects/compiler-rt && ${CLEAN} && git pull)
}

function main() {
    which git || abort 'please install git'
    which svn || abort 'please install svn'
    export CXXFLAGS="-DLLDB_DISABLE_PYTHON -DLLDB_DISABLE_CURSES -DLLDB_DISABLE_LIBEDIT -DLLVM_ENABLE_TERMINFO=0"
    if [[ ! -d llvm ]]; then
        setup
    else
        if [[ -d ${PREFIX} ]]; then
            echo
            echo "Warning: installing over existing ${PREFIX}"
            echo
        fi
        update
    fi
    build
}

main