# innounp — macOS (arm64) port

This is a fork that ports the **`innounp-2` console unpacker** to **native macOS**
(Apple Silicon / arm64), built with [Free Pascal](https://www.freepascal.org/).
The upstream project targets 32-bit Delphi on Windows and links x86 object files,
so it cannot be built on macOS as-is; this fork replaces the Windows-only pieces
with portable equivalents.

**Scope:** only the `innounp-2` *console* tool is ported. The Windows GUI in this
repository (`UnpackMain.pas` etc., Delphi VCL) is **not** ported and remains
Windows-only.

### Build (macOS)

```sh
cd innounp-2/sources
./build-macos.sh        # -> build/innounp
```

Requires `brew install fpc` and the Xcode command line tools (`clang`). See
[innounp-2/sources/BUILDING-macOS.md](innounp-2/sources/BUILDING-macOS.md) for
the full description of what the port changes.

### Status

Verified end-to-end against an Inno Setup 6.7 installer (LZMA2): info, `-l`, `-v`,
`-x` (extract) and `-t` (integrity test) all succeed, with CRC checks passing on
every file.

### Credits & license

- Upstream console + GUI by **Jürgen Rathlev** — [InnoUnpacker-Windows-GUI](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
- Original **innounp** — <https://sourceforge.net/projects/innounp>
- Inno Setup © Jordan Russell / Martijn Laan; bundled LZMA SDK, bzip2 and zlib
  retain their respective licenses (see `innounp-2/sources/licenses/`).

Licensed under the MIT License (see [LICENSE](LICENSE)). All upstream copyright
notices are retained. macOS port changes © 2026 Vladyslav Bahlai.

---

### Inno Setup Unpacker - Windows GUI v 2.2

#### Inspect and unpack InnoSetup archives

[Inno Setup](http://www.jrsoftware.org/isinfo.php) is a popular program
for making software installations. To verify and get files out of the self-extracting 
executable, these open source console applications are available:

- Original version [Innounp](http://sourceforge.net/projects/innounp) (can be used up to InnoSetup 6.1)
- Updated Unicode version [Innounp-2](innounp-2) (can be used up to InnoSetup 6.7.3)

**InnoUnpacker** is a graphical user interface (GUI) for these console applications
that makes the usage more comfortable.
The executable setup to be processed can be loaded via a file selection dialog, just 
by drag & drop, using the command line or by an entry in the Windows context menu for *exe* files. 
Immediately after opening, the basic file info of the setup is displayed. All other functions are activated by clicking on one of the buttons:

- General information about the setup
- A list of all included files 
- All supported languages 
- Verify setup file
- Select destination directory for extracted files
- Start file extraction

Optionally, you can specify whether only the installation script, the files matching a filter, or the files selected by the user should to be extracted.

**New:** Support of Windows Dark Mode

**Note on execution as portable program:** 
The program settings are normally stored in the InnoUnpack.ini file in the 
user's *Application data* folder. If the program is started from a device connected 
via USB, the folder of the executable file of the program is used instead. 
The same applies if the program is started with the command line option "/p".


[Application download](https://www.rathlev-home.de/index-e.html?tools/prog-e.html#unpack)

