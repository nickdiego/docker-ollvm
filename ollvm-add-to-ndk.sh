#!/usr/bin/env bash
# vim: ts=2 sw=2
#
#   Helper script for integrating and packaging O-LLVM toolchain into
#   official Android NDK.
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
Usage: ollvm-add-to-ndk.sh [options] <ollvm/binaries/path>

Build a volume-mapped local Obfuscator-LLVM inside docker container.

Available options:
  -h|--help               show this help message
  -n|--ndk-version        Android NDK version (Supported versions: r12b, r13b, r14b)
  -z|--no-gzip            Do not compress NDK using gzip

Manadatory arguments:
  ollvm/binaries/path     the path for the O-LLVM installation dir or tar.gz package
EOF
}

OLLVM_DIR=${OLLVM_DIR:-}
NDK_VERSION=${NDK_VERSION:-r14b}
GZIP_NDK=${GZIP_NDK:-1} # TODO move to command line option

TMP_DIR=$(readlink -f .tmp) # TODO suport cmdline option to overwrite this?
OUT_DIR=$PWD

# Process command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_usage
      exit 0
      ;;
    -n|--ndk-version)
      shift && NDK_VERSION=$1
      ;;
    -z|--no-gzip)
      GZIP_NDK=0
      ;;
    *)
      OLLVM_DIR=$(readlink -f $1)
  esac
  shift
done

# Initialize and validate NDK variables
NDK_DIR_NAME="android-ndk-${NDK_VERSION}"
NDK_FILE_NAME="${NDK_DIR_NAME}-linux-x86_64.zip"
NDK_DOWNLOAD_URL="https://dl.google.com/android/repository/${NDK_FILE_NAME}"
NDK_FILE_PATH="$TMP_DIR/$NDK_FILE_NAME"
NDK_DIR_PATH="$TMP_DIR/$NDK_DIR_NAME"

NDK_SHA1_r12b='170a119bfa0f0ce5dc932405eaa3a7cc61b27694'
NDK_SHA1_r13b='0600157c4ddf50ec15b8a037cfc474143f718fd0'
NDK_SHA1_r14b='becd161da6ed9a823e25be5c02955d9cbca1dbeb'
NDK_SHA1=$(eval "echo \$NDK_SHA1_${NDK_VERSION}")

if [ -z $NDK_SHA1 ]; then
  echo "Unsupported NDK_VERSION '$NDK_VERSION'"
  echo
  show_usage
  exit 1
fi

# Initialize and validate O-LLVM variables
if [ -z $OLLVM_DIR ] || [ ! -d $OLLVM_DIR ] || [ ! -e ${OLLVM_DIR}/bin/clang ]; then
  echo "Error: invalid OLLVM_DIR: '$OLLVM_DIR'"
  echo
  show_usage
  exit 1
fi

CLANG_PATH="${OLLVM_DIR}/bin/clang"
OLLVM_VERSION=$($CLANG_PATH -v 2>&1 | head -n1 | sed 's|^.\+clang version \([^ ]\+\).\+$|\1|g')
NDK_MODIFIED_DIR_NAME="${NDK_DIR_NAME}-ollvm${OLLVM_VERSION}"
OUT_FILE="${OUT_DIR}/${NDK_MODIFIED_DIR_NAME}-linux-x86_64.tar.gz"

echo "##"
echo "## Starting NDK packaging.."
echo "## O-LLVM directory: $OLLVM_DIR"
echo "## O-LLVM Version  : $OLLVM_VERSION"
echo "## NDK Version     : $NDK_VERSION"
echo "##"

mkdir -p $TMP_DIR
cd $TMP_DIR

# Move this to Dockerfile/image(?)
if [ ! -f $NDK_FILE_PATH ]; then
  echo "Downloading Official NDK ${NDK_VERSION}.."
  wget $NDK_DOWNLOAD_URL
fi

if ! echo "$NDK_SHA1 $NDK_FILE_NAME" | sha1sum -c; then
  echo "NDK Signature check failed!"
  exit 1
fi

if [ -e $NDK_DIR_PATH ]; then
  echo "Removing old NDK directory.."
  rm -rf $NDK_DIR_PATH
fi

echo "Unzipping NDK files into ${PWD}"
unzip -q $NDK_FILE_NAME

ndk_toolchains_config_dir="build/core/toolchains"
toolchain_name="ollvm${OLLVM_VERSION}"
prebuilt_dir="toolchains/$toolchain_name/prebuilt/linux-x86_64/"
setup_mk_regex="s|get-toolchain-root,llvm|get-toolchain-root,${toolchain_name}|g"

echo "Modifying NDK.."
cd $NDK_DIR_PATH
mkdir -pv $prebuilt_dir
cp -rfv ${OLLVM_DIR}/* ${prebuilt_dir}

for config_dir in ${ndk_toolchains_config_dir}/*-clang; do
  new_config_dir="${config_dir}-${toolchain_name}"
  echo -n "Configuring toolchain ${new_config_dir} .. "
  cp -rf $config_dir $new_config_dir
  sed -i "$setup_mk_regex" "$new_config_dir/setup.mk"
  echo done
done

cd $TMP_DIR
test -d $NDK_MODIFIED_DIR_NAME && rm -rf $NDK_MODIFIED_DIR_NAME
cp -r $NDK_DIR_NAME $NDK_MODIFIED_DIR_NAME

if (( GZIP_NDK )); then
  echo "Packaging modified NDK into $OUT_FILE"
  tar -czf $OUT_FILE $NDK_MODIFIED_DIR_NAME
else
  echo "Generated modified NDK into ${OUT_DIR}/${NDK_MODIFIED_DIR_NAME}"
  mv $NDK_MODIFIED_DIR_NAME $OUT_DIR
fi

# TODO Generate package checksum/signature?

echo "Done"
