#!/bin/sh
# Compiles the Inno Setup LZMA decoder sources (fetched from
# https://github.com/jrsoftware/issrc) for the host architecture.
#
# Both decoders ship their own LZMA SDK copy, and each exports a symbol named
# _LzmaDecode. Only the older size-optimized decoder (LzmaDecodeInno, used by
# the SetupLdr path) is called by that name from Pascal, so the new SDK's
# duplicate is localized to avoid a duplicate-symbol link error.
set -e
cd "$(dirname "$0")"

clang -O2 -c ISLzmaDec.c -o ISLzmaDec.tmp.o
ld -r ISLzmaDec.tmp.o -unexported_symbol _LzmaDecode -o ISLzmaDec.o
rm -f ISLzmaDec.tmp.o

clang -O2 -D_LZMA_OUT_READ -D_LZMA_IN_CB -c LzmaDecodeInno.c -o LzmaDecodeInno.o
