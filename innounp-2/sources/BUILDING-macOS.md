# Building innounp on macOS (Free Pascal)

This is a port of the console `innounp` (Inno Setup Unpacker) to macOS,
building as a native binary with Free Pascal. It has been tested on Apple
Silicon (arm64); the same sources also build for Intel (x86_64).

## Requirements

- Free Pascal 3.2.2+ — `brew install fpc`
- Xcode command line tools (for `clang`, used to compile the bundled LZMA
  decoder C sources) — `xcode-select --install`
- System `libz` and `libbz2` (ship with macOS)

## Build

```sh
cd sources
./build-macos.sh
```

This runs three steps (all idempotent):

1. `prep.sh` — expands the `Struct*`/`Compress*` version templates into
   `StructVer*.pas` / `CompressVer*.pas` and the `*.inc` lists (the POSIX
   replacement for `prep.bat`).
2. `lzma2c/build.sh` — compiles the Inno Setup LZMA decoder C sources
   (`ISLzmaDec.c`, `LzmaDecodeInno.c`, fetched from the upstream `jrsoftware/issrc`
   repository) into `.o` objects for the host architecture.
3. `fpc` — compiles the Pascal project to `build/innounp`.

## What the port changes

The original sources target 32-bit Delphi on Windows. The macOS port keeps the
Windows sources intact where possible and isolates platform code under
`sources/posix/`:

- **`posix/Winapi.Windows.pas`** — a small shim providing the Win32 types,
  constants and functions the sources use (file handles as POSIX fds, FILETIME
  conversions, console attributes via ANSI escapes, file attributes/times, etc.).
- **`posix/FileClass.pas`** — `TFile`/`TMemoryFile`/`TTextFile*` reimplemented
  on the POSIX file API (the original is preserved under `win32-orig/`).
- **`posix/PEResource.pas`** — a PE (Portable Executable) resource reader that
  replaces `LoadLibraryEx`/`FindResource`, used to read the SetupLdr offset
  table and the `PACKAGEINFO` resource directly from the installer image.
- **`posix/HashCompat.pas`** / **`posix/UITypes.pas`** / **`posix/WideStrUtils.pas`**
  — minimal replacements for the Delphi RTL units of the same name (pure-Pascal
  SHA-256, `TColor`/`TColors`, UTF-8 detection).
- **zlib / bzlib** now link the system `libz` / `libbz2` instead of statically
  linking the x86 `.obj` files.
- **LZMA / LZMA2** decoders are compiled from the upstream C sources for arm64
  instead of using the prebuilt x86 `.obj` files.
- **`ArcFour.pas`** and **`Int64Em.pas`** — the x86 assembly / linked-object
  implementations were replaced with portable pure-Pascal code (RC4 and 64-bit
  integer math).
- 64-bit pointer-arithmetic and dialect fixes throughout (e.g. `Lo()` returns a
  word, not a byte, in FPC — which had broken the CRC-32 routine).

## Status

Verified end-to-end against an Inno Setup 6.7 installer (LZMA2 compression):
`-i`, info, `-l`, `-v`, `-x` (extract) and `-t` (integrity test) all succeed,
with CRC checks passing on every file. On POSIX, extracted paths use `/` so
files land in a real directory tree.
