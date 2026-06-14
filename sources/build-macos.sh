#!/bin/sh
# Build innounp for macOS (Free Pascal, arm64 or x86_64).
#
# One-shot build: expands the Struct/Compress templates, compiles the bundled
# LZMA decoder C sources for the host architecture, then compiles the Pascal
# project. Links against the system libz and libbz2.
#
# Requirements: Free Pascal (brew install fpc) and the Xcode command line tools
# (clang). Run from the sources/ directory.
set -e
cd "$(dirname "$0")"

# 1. Expand the version templates (idempotent) if not already done.
if [ ! -f StructList.inc ] || [ ! -f CompressList.inc ]; then
  ./prep.sh
fi

# 2. Compile the LZMA decoder objects for the host architecture.
sh lzma2c/build.sh

# 3. Compile the Pascal project.
mkdir -p build
fpc -Mdelphiunicode -Sg -O2 -veiwn -Fuposix -Fucompression -FUbuild -FEbuild \
    -oinnounp innounp.dpr "$@"

echo "Built: $(pwd)/build/innounp"
