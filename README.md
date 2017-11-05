DEPRECATED. This code has now been ported to https://github.com/mapbox/mason. To build or install llvm via mason:

 - download mason
 - run: `mason install llvm 6.0.0`
 
More details at https://github.com/mapbox/mason/blob/master/scripts/llvm/base/README.md

--------

Track and build llvm master and friends

[![Build Status](https://travis-ci.org/springmeyer/build-llvm.svg)](https://travis-ci.org/springmeyer/build-llvm)

Currently builds head of:

  - llvm
  - clang
  - clang-tools-extra
  - include-what-you-use
  - compiler-rt
  - lldb (optionally, currently disabled)

## Depends

  - c++11 compiler
  - ninja
  - cmake
  - git

## Usage

To build and install everything first ensure ninja and cmake are on your path.

Then do:

```
./build.sh
```

Then prepare to wait for ~30 minutes.


Installs into `/opt/llvm/` by default. Do:

```
export PATH=/opt/llvm/bin:${PATH}
```

To use your custom `clang++`

Or request installation in a custom directory:

```
PREFIX=/usr/local ./build.sh
```

You can re-run `./build.sh` at any time. It will pull the latest updates and re-build. Fairly frequently you will hit compiler errors because the llvm, clang, or other developers have let things get out of sync. To avoid this I plan to
modify the script to use tags, but not gotten around to this yet.


