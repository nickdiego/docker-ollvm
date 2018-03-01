#!/usr/bin/env bash
# vim: ts=2 sw=2
#
#   Helper script for building Obfuscator-LLVM in a Docker container
#
#   Copyright (c) 2017 Nick Diego Yamane <nick@diegoyam.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

function show_usage() {
  cat << EOF
Usage: ollvm-build.sh <path/to/ollvm/src>

Build a volume-mapped local Obfuscator-LLVM inside docker container.
If no arguments are given, 'bash' is executed in the build container
instead of the build script.

Available options:
  -h|--help           show this help message

Positional arguments:
  path/to/ollvm/src   the O-LLVM source directory path

All options after '--' are passed to CMake invocation.
EOF
}

# In docker-mode should be set in Dockerfile
# In host-mode, set using command-line arg
OLLVM_DIR=${OLLVM_DIR:-}
CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-Release}
DOCKER_MODE=0

BUILD_DIR_NAME='build_docker'
INSTALL_DIR_NAME='_installed_'

declare -a CMAKE_ARGS

# Process command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
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
  if [ ! -f "$OLLVM_DIR/llvm.spec.in" ]; then
      echo "Invalid O-LLVM source dir. Aborting..."
      exit 1
  fi

  GUEST_BUILD_DIR="$OLLVM_DIR/$BUILD_DIR_NAME"
  GUEST_INSTALL_DIR="$GUEST_BUILD_DIR/$INSTALL_DIR_NAME"
  CMAKE_ARGS+=( "-DCMAKE_INSTALL_PREFIX='$GUEST_INSTALL_DIR'" )

  BUILD_TYPE_SET=0
  for i in ${CMAKE_ARGS[@]}; do
    grep "^-DCMAKE_BUILD_TYPE=" <<< "$i" && BUILD_TYPE_SET=1
  done
  (( BUILD_TYPE_SET )) || CMAKE_ARGS+=( "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" )

  mkdir -p "$GUEST_BUILD_DIR"
  pushd "$GUEST_BUILD_DIR"
  echo "Running build"
  cmake -GNinja "${CMAKE_ARGS[@]}" "$OLLVM_DIR"
  ninja -j3 install
  # TODO pakage install dir

else # script called from host

  if [ -z $OLLVM_DIR ]; then
    echo "O-LLVM source dir not set. Entering in bash mode.."
    show_usage
    DOCKER_CMD='bash'
  else
    DOCKER_CMD="/scripts/ollvm-build.sh --docker -- ${CMAKE_ARGS[@]}"
  fi

  DOCKER_IMAGE_NAME='nickdiego/ollvm-build'
  DOCKER_CONTAINER_NAME='ollvm-build'
  DOCKER_OPTS=( '--name' $DOCKER_CONTAINER_NAME --rm  -v "$OLLVM_DIR:/ollvm/src" )

  echo "Starting O-LLVM build.."
  echo "Source dir  : $OLLVM_DIR"
  echo "Docker image: $DOCKER_IMAGE_NAME"
  docker run "${DOCKER_OPTS[@]}" -it $DOCKER_IMAGE_NAME $DOCKER_CMD
  echo "Build finished successfully. Output directory: $OLLVM_DIR/$BUILD_DIR_NAME"
fi
