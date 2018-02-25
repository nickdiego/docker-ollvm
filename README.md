## Dockerized build and helper scripts for Obfuscator-LLVM 

This repository provides a Dockerfile and some helper shell scripts useful to easily build Obfuscator-LLVM project from source as well as configuring it as a Android NDK toolchain. The scripts can be used both as standalone tools and inside the Docker image.  

#### Basic usage

- Build O-LLVM within a docker container, using `ollvm/source/dir` as source directory 
The output build directory will be in `path/to/ollvm/source/dir/build_docker`.
```bash
./ollvm-build.sh ollvm/source/dir
```

- Add O-LLVM toolchain into Official Android NDK, using `ollvm/artifacts/dir` as binary directory
(result from a previous OLLVM build). The output NDK package will be generated into the current
working directory.
```bash
./ollvm-add-to-ndk.sh ollvm/artifacts/dir
```

#### Using in Gitlab-CI

Another use case where these scripts are very useful is to integrate O-LLVM build process into a Continuous Integration
system, which is very handy when researching/hacking O-LLVM (E.g: Adding some experimental features or improving
the existing ones).
Below is an example on how to build O-LLVM and generate a NDK with O-LLVM toolchain using the docker image built from this repository:

```yaml
...
build:
  stage: build
  script:
  ┆ - OLLVM_DIR=$PWD /scripts/ollvm-build.sh --docker
  ┆ - tar -cfz ollvm-4.0.tgz build_docker/_installed_/*
  artifacts:
  ┆ paths:
  ┆ ┆ - ollvm-4.0.tgz
  stage: build

package:
  stage: repackage_ndk
  script:
  ┆ - /scripts/ollvm-add-to-ndk.sh build_docker/_installed_
  artifacts:
  ┆ paths:
  ┆ ┆ - android-ndk-r14b-ollvm4.0-linux-x86_64.tar.gz
...
```

#### About Obfuscator-LLVM

O-LLVM is an open-source fork of the LLVM compilation suite able to provide increased software security through code obfuscation and tamper-proofing. As we currently mostly work at the Intermediate Representation (IR) level, our tool is compatible with all programming languages (C, C++, Objective-C, Ada and Fortran) and target platforms (x86, x86-64, PowerPC, PowerPC-64, ARM, Thumb, SPARC, Alpha, CellSPU, MIPS, MSP430, SystemZ, and XCore) currently supported by LLVM.

More information: https://github.com/obfuscator-llvm/obfuscator/wiki


##### Docker Hub

https://hub.docker.com/r/nickdiego/ollvm-build/

