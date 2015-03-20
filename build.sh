#!/usr/bin/env bash

set -e -u
set -o pipefail

PREFIX=${PREFIX:-"/opt/llvm/"}

function abort { >&2 echo -e "\033[1m\033[31m$1\033[0m"; exit 1; }

function setup() {
    git clone --depth 1 http://llvm.org/git/llvm.git
    cd llvm/tools
    git clone --depth 1 http://llvm.org/git/clang.git
    git clone --depth 1 http://llvm.org/git/lldb.git
    cd clang/tools
    git clone --depth 1 http://llvm.org/git/clang-tools-extra.git
    svn co http://include-what-you-use.googlecode.com/svn/trunk/ include-what-you-use
    perl -p -i -e 's/diagtool/diagtool include-what-you-use/g' Makefile
    cd ../../../
    cd ./projects
    git clone --depth 1 http://llvm.org/git/compiler-rt.git
    cd ../
    git config branch.master.rebase true
    ./configure --prefix=${PREFIX} --enable-clang-static-analyzer --enable-optimized
    make && make install
}

function update() {
    CLEAN=""
    if [[ -d ${PREFIX} ]]; then
        echo "Please remove $PREFIX before continuing"
        exit 1
    fi
    cd llvm
    ${CLEAN} && git pull
    cd tools/lldb
    ${CLEAN} && git pull
    cd ../../
    cd tools/clang
    ${CLEAN} && git pull
    cd tools/clang-tools-extra
    ${CLEAN} && git pull
    cd ../include-what-you-use
    ${CLEAN} && svn up
    cd ../../../../projects/compiler-rt/
    ${CLEAN} && git pull
    cd ../../
    # TODO - get this working or embed custom libc++
    #CLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/6.0/include:/usr/include
    #CPPLIB=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1/
    #  --with-c-include-dirs=${CLIB}:${CPPLIB}
    ./configure --prefix=${PREFIX} --enable-optimized --enable-clang-static-analyzer --enable-libcpp --enable-cxx11 --disable-assertions
    time make ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 -j2
    make install ENABLE_OPTIMIZED=1 DISABLE_ASSERTIONS=1 -j2
    cp Release/bin/clang "${PREFIX}/bin/clang"
    strip -x ${PREFIX}/bin/clang
}

function main() {
    which swig || abort 'please install swig'
    if [[ ! -d llvm ]]; then
        setup
    else
        update
    fi
}

main