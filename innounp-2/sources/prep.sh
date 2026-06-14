#!/bin/sh
# POSIX port of prep.bat: expand the Struct/Compress templates before first build.
cd "$(dirname "$0")"
rm -f StructList.inc CompressList.inc StructVer*.pas CompressVer*.pas

while read -r ver suf || [ -n "$ver" ]; do
  [ -z "$ver" ] && continue
  sed -e "s/DEFVER/$ver/g" -e "s/_EXTSUF_/$suf/g" StructTemplate.pas > "StructVer$ver$suf.pas"
  printf 'StructVer%s%s,\n' "$ver" "$suf" >> StructList.inc
done < StructList
echo empty >> StructList.inc

while read -r ver _ || [ -n "$ver" ]; do
  [ -z "$ver" ] && continue
  sed -e "s/DEFVER/$ver/g" CompressTemplate.pas > "CompressVer$ver.pas"
  printf 'CompressVer%s,\n' "$ver" >> CompressList.inc
done < CompressList
echo empty >> CompressList.inc
