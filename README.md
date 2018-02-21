## Dockerized build and helper scripts for Obfuscator-OLLVM 

_Work in Progress :)_


**Basic usage:**

- Run a build of O-LLVM in the docker container, using `ollvm/source/dir` as source directory 
The output build directory will be in `path/to/ollvm/source/dir/build_docker`.
```bash
./ollvm-build.sh ollvm/source/dir
```

- Add O-LLVM toolchain into Android Official NDK, using `ollvm/binaries/dir` as binary directory
(result from a previous OLLVM build). The output NDK package will be generated in the directory
where the script has been executed from.
```bash
./ollvm-build.sh ollvm/source/dir
```
