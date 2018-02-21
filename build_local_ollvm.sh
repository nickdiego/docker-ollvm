#!/usr/bin/env bash
# vim: ts=2 sw=2
#
#===- llvm/utils/docker/scripts/build_install_llvm.sh ---------------------===//
#
#                     The LLVM Compiler Infrastructure
#
# This file is distributed under the University of Illinois Open Source
# License. See LICENSE.TXT for details.
#
#===-----------------------------------------------------------------------===//
#
# Adapted by Nick Yamane to build a volume-mapped local Obfuscator-LLVM repository
#
#===-----------------------------------------------------------------------===//

set -e

function show_usage() {
  cat << EOF
Usage: build_local_ollvm.sh --docker [cmake-args]
Usage: build_local_ollvm.sh <path/to/ollvm/src>

Build a volume-mapped local Obfuscator-LLVM inside docker container.

Available options:
  -d|--docker         run in docker-mode
  -h|--help           show this help message

All options after '--' are passed to CMake invocation.
EOF
}

DOCKER_MODE=0
OLLVM_DIR=""
BUILD_DIR_NAME='build_docker'
INSTALL_DIR_NAME='_installed_'

GUEST_SRC_DIR=/ollvm/src
GUEST_BUILD_DIR="$GUEST_SRC_DIR/$BUILD_DIR_NAME"
GUEST_INSTALL_DIR="$GUEST_BUILD_DIR/$INSTALL_DIR_NAME"

CMAKE_ARGS=(
    '-DCMAKE_BUILD_TYPE=Release'
    "-DCMAKE_INSTALL_PREFIX='$GUEST_INSTALL_DIR'"
)

# Process command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --)
      ;;
    -d|--docker)
      DOCKER_MODE=1
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      if [ -d "$1" ]; then
        OLLVM_DIR=$(readlink -f $1)
        shift
      else
        CMAKE_ARGS+=( "$@" )
        shift $#
      fi
  esac
done

if (( DOCKER_MODE )); then

  # Checking source folder sanity-check
  if [ ! -f "$GUEST_SRC_DIR/llvm.spec.in" ]; then
      echo "Invalid O-LLVM source dir. Aborting..."
      exit 1
  fi

  mkdir -p "$GUEST_BUILD_DIR"
  pushd "$GUEST_BUILD_DIR"
  echo "Running build"
  cmake -GNinja "${CMAKE_ARGS[@]}" "$GUEST_SRC_DIR"
  ninja -j3 install

else # script called from host

  if [ -z $OLLVM_DIR ]; then
    echo "Error: OLLVM_DIR not set!"
    show_usage
    exit 1
  fi

  DOCKER_IMAGE_NAME='nickdiego/ollvm'
  DOCKER_CONTAINER_NAME='ollvm-builder'
  DOCKER_OPTS=( '--name' $DOCKER_CONTAINER_NAME --rm  -v "$OLLVM_DIR:/ollvm/src" )

  echo "Starting O-LLVM build.."
  echo "Source dir  : $OLLVM_DIR"
  echo "Docker image: $DOCKER_IMAGE_NAME"
  docker run "${DOCKER_OPTS[@]}" -it $DOCKER_IMAGE_NAME
  echo "Build finished successfully. Output directory: $OLLVM_DIR/$BUILD_DIR_NAME"

fi

echo "Done"
