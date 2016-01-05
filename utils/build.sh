#!/bin/bash
#
# Copyright (C) 2015 Virgil Security Inc.
#
# Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     (1) Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#     (2) Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#     (3) Neither the name of the copyright holder nor the names of its
#     contributors may be used to endorse or promote products derived from
#     this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Color constants
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_ORANGE='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_YELLOW='\033[1;33m'
COLOR_WHITE='\033[1;37m'
COLOR_RESET='\033[0m'

# Util functions
function show_usage {
    if [ ! -z "$1" ]; then
        echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}"
    fi
    echo -e "This script helps to build crypto library for variety of languages and platforms."
    echo -e "Common reuirements: CMake 3.0.5, Python, PyYaml, SWIG 3.0.7."
    echo -e "${COLOR_BLUE}Usage: ${BASH_SOURCE[0]} [<target>] [<src_dir>] [<build_dir>] [<install_dir>]${COLOR_RESET}"
    echo -e "  - <target> - (default = cpp) one of the next values:"
    echo -e "    * cpp              - build C++ library;"
    echo -e "    * osx              - build framework for Apple OS X, requirements: OS X, Xcode;"
    echo -e "    * ios              - build framework for Apple iOS, requirements: OS X, Xcode;"
    echo -e "    * applewatchos     - build framework for Apple WatchOS, requirements: OS X, Xcode;"
    echo -e "    * appletvos        - build framework for Apple TVOS, requirements: OS X, Xcode;"
    echo -e "    * php              - build PHP library, requirements: php-dev;"
    echo -e "    * python           - build Python library;"
    echo -e "    * ruby             - build Ruby library;"
    echo -e "    * java             - build Java library, requirements: \$JAVA_HOME;"
    echo -e "    * java_android     - build Java library under Android platform, requirements: \$ANDROID_NDK;"
    echo -e "    * net              - build .NET library, requirements: .NET or Mono;"
    echo -e "    * net_ios          - build .NET library under Apple iOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "    * net_applewatchos - build .NET library under WatchOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "    * net_appletvos    - build .NET library under TVOS platform, requirements: Mono, OS X, Xcode;"
    echo -e "    * net_android      - build .NET library under Android platform, requirements: Mono, \$ANDROID_NDK;"
    echo -e "    * asmjs            - build AsmJS library;"
    echo -e "    * nodejs           - build NodeJS module, requirements: run 'source /path/to/emsdk_env.sh';"
    echo -e "    * as3              - build ActionScript library, requirements: \$CROSSBRIDGE_HOME, \$FLEX_HOME;"
    echo -e "    * pnacl            - build Portable Native library for Google Chrome, requirements: \$NACL_SDK_ROOT."
    echo -e "  - <src_dir>     - (default = .) path to the directory where root CMakeLists.txt file is located"
    echo -e "  - <build_dir>   - (default = build/<target>) path to the directory where temp files will be stored"
    echo -e "  - <install_dir> - (default = install/<target>) path to the directory where library files will be installed".

    exit ${2:0}
}

function show_info {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1"
}

function show_error {
    echo -e "${COLOR_RED}[ERROR] $1${COLOR_RESET}"
    exit 1
}

function abspath() {
  (
    if [ -d "$1" ]; then
        cd "$1" && pwd -P
    else
        echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
    fi
  )
}

# Check arguments
SCRIPT_DIR=$(abspath "${BASH_SOURCE[0]}")
CURRENT_DIR=$(abspath .)

if [ ! -z "$1" ]; then
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_usage
    else
        TARGET="$1"
    fi
else
    TARGET="cpp"
fi
show_info "<target> : ${TARGET}"

if [ ! -z "$2" ]; then
    SRC_DIR=$(abspath "$2")
else
    SRC_DIR="${CURRENT_DIR}"
fi
show_info "<src_dir>: ${SRC_DIR}"

if [ ! -f "${SRC_DIR}/CMakeLists.txt" ]; then
    show_usage "Source directory does not contain root CMakeLists.txt file!" 1
fi

if [ ! -z "$3" ]; then
    mkdir -p "$3"
    BUILD_DIR=$(abspath "$3")
else
    BUILD_DIR="${CURRENT_DIR}/build/${TARGET}"
    mkdir -p "${BUILD_DIR}"
fi
show_info "<build_dir>: ${BUILD_DIR}"

if [ ! -z "$4" ]; then
    mkdir -p "$4"
    INSTALL_DIR=$(abspath "$4")
else
    INSTALL_DIR="${CURRENT_DIR}/install/${TARGET}"
    mkdir -p "${INSTALL_DIR}"
fi
show_info "<install_dir>: ${INSTALL_DIR}"

# Define common build parameters
CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release"

if [[ ${TARGET} =~ ^(cpp|osx|java|net|php|python|ruby|nodejs)$ ]]; then
    if [ "$(uname -s | tr '[:upper:]' '[:lower:]')" == "darwin" ]; then
        CMAKE_ARGS+=" -DPLATFORM_ARCH=universal -DCMAKE_OSX_ARCHITECTURES=i386;x86_64"
    else
        CMAKE_ARGS+=" -DPLATFORM_ARCH=$(uname -m)"
    fi
fi

if [ ! -z "${INSTALL_DIR}" ]; then
    CMAKE_ARGS+=" -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}"
fi

# Go to the build directory
cd "${BUILD_DIR}" && rm -fr ./*

# Build for native platforms
if [[ ${TARGET} =~ ^(cpp|java|net|php|python|ruby|nodejs)$ ]]; then
    cmake ${CMAKE_ARGS} -DLANG=${TARGET} "${SRC_DIR}"
    make -j4 install
fi

if [ "${TARGET}" == "osx" ]; then
    # Build
    cmake ${CMAKE_ARGS} -DLANG=cpp "${SRC_DIR}"
    make -j4 install
    # Create framework
    MAKE_BUNDLE="$(dirname "${SCRIPT_DIR}")/make_bundle.sh"
    ${MAKE_BUNDLE} VirgilCrypto "${INSTALL_DIR}" "${INSTALL_DIR}"
    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
fi

# Build for embedded plaforms
if [ "${TARGET}" == "ios" ] || [ "${TARGET}" == "appletvos" ] || [ "${TARGET}" == "applewatchos" ]; then
    CMAKE_ARGS+=" -DPLATFORM=${TARGET}"
    # Build for device
    cmake ${CMAKE_ARGS} -DLANG=cpp -DINSTALL_LIB_DIR_NAME=lib/dev -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/apple.toolchain.cmake" "${SRC_DIR}"
    make -j4 install
    # Build for simulator
    rm -fr ./*
    cmake ${CMAKE_ARGS} -DLANG=cpp -DINSTALL_LIB_DIR_NAME=lib/sim -DSIMULATOR=ON -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/apple.toolchain.cmake" "${SRC_DIR}"
    make -j4 install
    # Create framework
    MAKE_BUNDLE="$(dirname "${SCRIPT_DIR}")/make_bundle.sh"
    ${MAKE_BUNDLE} VirgilCrypto "${INSTALL_DIR}" "${INSTALL_DIR}"
    rm -fr "${INSTALL_DIR:?}/include"
    rm -fr "${INSTALL_DIR:?}/lib"
fi

if [[ "${TARGET}" == *"android"* ]]; then
    if [ ! -d "$ANDROID_NDK" ]; then
        show_usage "Enviroment \$ANDROID_NDK is not defined!"
    fi
    if [ "${TARGET}" == "java_android" ]; then
        CMAKE_ARGS+=" -DLANG=java"
    elif [ "${TARGET}" == "net_android" ]; then
        CMAKE_ARGS+=" -DLANG=net"
    else
        show_usage "Unsupported target: ${TARGET}!"
    fi
    function build_android() {
        # Build architecture: $1
        rm -fr ./*
        cmake ${CMAKE_ARGS} -DANDROID_ABI="$1" -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/android.toolchain.cmake" "${SRC_DIR}"
        make -j4 install
    }
    build_android x86
    build_android x86_64
    build_android mips
    build_android mips64
    build_android armeabi
    build_android armeabi-v7a
    build_android arm64-v8a
    # Pack all JNI libs to jar
    cd "${INSTALL_DIR}/lib" || show_error "Fail to pack JNI libs to JAR due to missed folder: ${INSTALL_DIR}/lib"
    zip -r virgil_crypto_java_jni.jar lib
    rm -fr lib
    cd - || show_error "Failed to cd -"
fi

if [[ ${TARGET} =~ ^net_(ios|appletvos|applewatchos)$ ]]; then
    cmake ${CMAKE_ARGS} -DLANG=net -DENABLE_BITCODE=NO -DPLATFORM=${TARGET/net_/} -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/apple.toolchain.cmake" "${SRC_DIR}"
    make -j4 install
fi

if [ "${TARGET}" == "asmjs" ]; then
    if [ ! -d "$EMSDK_HOME" ]; then
        show_usage "Enviroment \$EMSDK_HOME is not defined!"
    fi
    source "${EMSDK_HOME}/emsdk_env.sh"
    cmake ${CMAKE_ARGS} -DLANG=asmjs -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake" "${SRC_DIR}"
    make -j4 install
fi

if [ "${TARGET}" == "as3" ]; then
    if [ ! -d "$CROSSBRIDGE_HOME" ]; then
        show_usage "Enviroment \$CROSSBRIDGE_HOME is not defined!"
    fi
    if [ ! -d "$FLEX_HOME" ]; then
        show_usage "Enviroment \$FLEX_HOME is not defined!"
    fi
    cmake ${CMAKE_ARGS} -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/as3.toolchain.cmake" "${SRC_DIR}"
    make -j4 install
fi

if [ "${TARGET}" == "pnacl" ]; then
    if [ ! -d "$NACL_SDK_ROOT" ]; then
        show_usage "Enviroment \$NACL_SDK_ROOT is not defined!"
    fi
    cmake ${CMAKE_ARGS} -DCMAKE_TOOLCHAIN_FILE="${SRC_DIR}/cmake/pnacl.toolchain.cmake" "${SRC_DIR}"
    make -j4 install
fi

if [[ ${TARGET} =~ (ios|appletvos|applewatchos|android) ]]; then
    ARCH_NAME=$(cat "${BUILD_DIR}/lib_name.txt")
else
    ARCH_NAME=$(cat "${BUILD_DIR}/lib_name_full.txt")
fi

# Archive installed libraries and remove all except archive
cd "${INSTALL_DIR}" && tar -czvf "${ARCH_NAME}.tar.gz" -- *
find . ! -path . -type d -exec rm -fr {} +
