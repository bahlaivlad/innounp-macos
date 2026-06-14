# innounp — macOS (arm64) port

A native **macOS** build of **innounp**, the console unpacker for
[Inno Setup](https://www.jrsoftware.org/isinfo.php) installers. It inspects and
extracts files from Inno Setup self-extracting `.exe` installers.

This is a port of the `innounp-2` console tool to macOS (Apple Silicon / arm64),
built with [Free Pascal](https://www.freepascal.org/). The upstream project
targets 32-bit Delphi on Windows and links x86 object files, so it cannot be
built on macOS as-is; this fork replaces the Windows-only pieces with portable
equivalents. The same sources also build for Intel (x86_64).

> Scope: only the `innounp` **console** tool is ported. The upstream
> repository also contains a Windows VCL **GUI** (`InnoUnpacker`); that is
> Windows-only and is **not** included here.

## Build

```sh
cd sources
./build-macos.sh        # -> build/innounp
```

Requirements:

- Free Pascal 3.2.2+ — `brew install fpc`
- Xcode command line tools (for `clang`) — `xcode-select --install`
- System `libz` and `libbz2` (ship with macOS)

See [sources/BUILDING-macOS.md](sources/BUILDING-macOS.md) for a full description
of what the port changes and how the build is wired together.

## Usage

```
innounp [command] [options] <setup.exe> [@filelist] [filemask ...]
```

Common commands:

| Command | Action |
|---------|--------|
| *(none)* | show general information about the installer |
| `-v` | verbose list of files (with sizes and timestamps) |
| `-l` | list supported languages |
| `-x` | extract files (into a real directory tree on macOS) |
| `-e` | extract without paths |
| `-t` | test files for integrity (CRC) |
| `-i` | list all supported Inno Setup versions |

Add `-b` for non-interactive (batch) mode and `-dDIR` to choose an output
directory. Run `innounp` with no arguments for the full option list.

## Status

Verified end-to-end against an Inno Setup 6.7 installer (LZMA2 compression):
info, `-l`, `-v`, `-x` and `-t` all succeed, with CRC integrity checks passing
on every file. The zlib/bzip2 code paths (used by older Inno Setup installers)
compile and link against the system libraries but have not been runtime-tested.

## Credits & license

- Upstream console + GUI by **Jürgen Rathlev** —
  [InnoUnpacker-Windows-GUI](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
- Original **innounp** — <https://sourceforge.net/projects/innounp>
- Inno Setup © Jordan Russell / Martijn Laan. The bundled LZMA SDK, bzip2 and
  zlib retain their respective licenses (see `sources/licenses/`).

Licensed under the MIT License (see [LICENSE](LICENSE)); all upstream copyright
notices are retained. macOS port changes © 2026 Vladyslav Bahlai.
