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
Usage: build_local_ollvm.sh --docker [cmake-args]
Usage: build_local_ollvm.sh <path/to/ollvm/src>

Build a volume-mapped local Obfuscator-LLVM inside docker container.

Available options:
  -d|--docker         run in docker-mode
  -h|--help           show this help message

All options after '--' are passed to CMake invocation.
EOF
}

# In docker-mode should be set in Dockerfile
# In host-mode, set using command-line arg
OLLVM_DIR=${OLLVM_DIR:-}
OLLVM_VERISON='3.6'

DOCKER_MODE=0
BUILD_DIR_NAME='build_docker'
INSTALL_DIR_NAME='_installed_'

GUEST_SRC_DIR="$OLLVM_DIR/src"
GUEST_BUILD_DIR="$GUEST_SRC_DIR/$BUILD_DIR_NAME"
GUEST_INSTALL_DIR="$GUEST_BUILD_DIR/$INSTALL_DIR_NAME"

CMAKE_ARGS=(
    '-DCMAKE_BUILD_TYPE=Release'
    "-DCMAKE_INSTALL_PREFIX='$GUEST_INSTALL_DIR'"
)

NDK_VERSION='r14b'
NDK_DIR_NAME="android-ndk-${NDK_VERSION}"
NDK_MODIFIED_DIR_NAME="${NDK_DIR_NAME}-ollvm${OLLVM_VERISON}"
NDK_FILE_NAME="${NDK_DIR_NAME}-linux-x86_64.zip"
NDK_DOWNLOAD_URL="https://dl.google.com/android/repository/${NDK_FILE_NAME}"
NDK_ORIGINAL_SHA1='becd161da6ed9a823e25be5c02955d9cbca1dbeb'

GUEST_NDK_ROOT_PATH="$GUEST_BUILD_DIR/_ndk_"
GUEST_NDK_FILE_PATH="$GUEST_NDK_ROOT_PATH/$NDK_FILE_NAME"
GUEST_NDK_DIR_PATH="$GUEST_NDK_ROOT_PATH/$NDK_DIR_NAME"

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

function download_and_customize_ndk() {
  echo "Starting NDK packaging.."
  mkdir -p $GUEST_NDK_ROOT_PATH
  cd $GUEST_NDK_ROOT_PATH

  # Move this to Dockerfile/image(?)
  if [ ! -f $GUEST_NDK_FILE_PATH ]; then
    echo "Downloading Official NDK ${NDK_VERSION}.."
    wget $NDK_DOWNLOAD_URL
  fi

  if ! echo "$NDK_ORIGINAL_SHA1 $NDK_FILE_NAME" | sha1sum -c; then
    echo "NDK Signature check failed!"
    exit 1
  fi

  if [ -e $GUEST_NDK_DIR_PATH ]; then
    echo "Removing old NDK directory.."
    rm -rf $GUEST_NDK_DIR_PATH
  fi

  echo "Unzipping NDK files into ${PWD}"
  unzip -q $NDK_FILE_NAME

  local ndk_toolchains_config_dir="build/core/toolchains"
  local toolchain_name="ollvm-${OLLVM_VERISON}"
  local prebuilt_dir="toolchains/$toolchain_name/prebuilt/linux-x86_64/"
  local setup_mk_regex="s|get-toolchain-root,llvm|get-toolchain-root,${toolchain_name}|g"

  echo "Modifying NDK.."
  cd $GUEST_NDK_DIR_PATH
  mkdir -pv $prebuilt_dir
  mv -fv ${GUEST_INSTALL_DIR}/* ${prebuilt_dir}

  for config_dir in ${ndk_toolchains_config_dir}/*-clang; do
    new_config_dir="${config_dir}-${toolchain_name}"
    echo -n "Configuring toolchain ${new_config_dir} .. "
    cp -rf $config_dir $new_config_dir
    sed -i "$setup_mk_regex" "$new_config_dir/setup.mk"
    echo done
  done

  local output_file="${GUEST_NDK_ROOT_PATH}/${NDK_MODIFIED_DIR_NAME}-linux-x86_64.tar.gz"
  echo "Packaging modified NDK into $output_file"
  cd $GUEST_NDK_ROOT_PATH
  test -d $NDK_MODIFIED_DIR_NAME && rm -rf $NDK_MODIFIED_DIR_NAME
  mv $NDK_DIR_NAME $NDK_MODIFIED_DIR_NAME
  tar -czf $output_file $NDK_MODIFIED_DIR_NAME
}

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
  download_and_customize_ndk

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
