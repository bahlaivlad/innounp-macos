unit Winapi.Windows;

{
  Minimal POSIX replacement for the Winapi.Windows unit, providing just the
  types, constants and functions that the innounp sources use.
  Part of the macOS/FPC port of innounp.

  File handles (THandle) are POSIX file descriptors.
  FILETIME keeps Windows semantics: 100ns intervals since 1601-01-01 UTC.
  Console attributes are emulated with ANSI escape sequences.
}

interface

{$MODE DELPHIUNICODE}

uses
  BaseUnix, Unix, SysUtils;

type
  DWORD   = Cardinal;
  PDWORD  = ^DWORD;
  BOOL    = LongBool;
  UINT    = Cardinal;
  ULONG   = Cardinal;
  LONG    = Longint;
  SHORT   = Smallint;
  USHORT  = Word;
  LPSTR   = PAnsiChar;
  LPCSTR  = PAnsiChar;
  LPWSTR  = PWideChar;
  LPCWSTR = PWideChar;
  HMODULE = PtrUInt;
  HLOCAL  = Pointer;
  HWND    = PtrUInt;
  LANGID  = Word;
  UCHAR   = Byte;
  { HKEY must be 4 bytes: the Inno on-disk TSetupRegistryEntry.RootKey field is a
    32-bit value (matching 32-bit Delphi where HKEY=THandle=Longint). Using a
    pointer-width type here makes the packed record 4 bytes too large, so
    SECompressedBlockRead over-reads the per-entry remainder and desyncs every
    setup that contains registry entries. }
  HKEY    = DWORD;

  TFileTime = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;
  FILETIME = TFileTime;
  PFileTime = ^TFileTime;

  TSIDIdentifierAuthority = record
    Value: array[0..5] of Byte;
  end;
  PSIDIdentifierAuthority = ^TSIDIdentifierAuthority;

  { Windows-style field names (wYear...) as the Inno Setup code expects;
    FPC's SysUtils.TSystemTime uses different names (Year...). }
  TSystemTime = record
    wYear: Word;
    wMonth: Word;
    wDayOfWeek: Word;
    wDay: Word;
    wHour: Word;
    wMinute: Word;
    wSecond: Word;
    wMilliseconds: Word;
  end;
  PSystemTime = ^TSystemTime;

  TCoord = record
    X: SHORT;
    Y: SHORT;
  end;

  TSmallRect = record
    Left: SHORT;
    Top: SHORT;
    Right: SHORT;
    Bottom: SHORT;
  end;

  TConsoleScreenBufferInfo = record
    dwSize: TCoord;
    dwCursorPosition: TCoord;
    wAttributes: Word;
    srWindow: TSmallRect;
    dwMaximumWindowSize: TCoord;
  end;
  PConsoleScreenBufferInfo = ^TConsoleScreenBufferInfo;

const
  INVALID_HANDLE_VALUE = THandle(-1);

  GENERIC_READ  = DWORD($80000000);
  GENERIC_WRITE = DWORD($40000000);

  FILE_SHARE_READ  = 1;
  FILE_SHARE_WRITE = 2;

  CREATE_NEW        = 1;
  CREATE_ALWAYS     = 2;
  OPEN_EXISTING     = 3;
  OPEN_ALWAYS       = 4;
  TRUNCATE_EXISTING = 5;

  FILE_ATTRIBUTE_READONLY  = 1;
  FILE_ATTRIBUTE_HIDDEN    = 2;
  FILE_ATTRIBUTE_SYSTEM    = 4;
  FILE_ATTRIBUTE_DIRECTORY = $10;
  FILE_ATTRIBUTE_ARCHIVE   = $20;
  FILE_ATTRIBUTE_NORMAL    = $80;
  INVALID_FILE_ATTRIBUTES  = DWORD($FFFFFFFF);

  FILE_BEGIN   = 0;
  FILE_CURRENT = 1;
  FILE_END     = 2;

  { Win32 error codes kept for source compatibility; GetLastError on this
    platform returns errno values, so these are only raised explicitly. }
  ERROR_SUCCESS          = 0;
  ERROR_FILE_NOT_FOUND   = 2;
  ERROR_PATH_NOT_FOUND   = 3;
  ERROR_ACCESS_DENIED    = 5;
  ERROR_INVALID_HANDLE   = 6;
  ERROR_NO_MORE_FILES    = 18;
  ERROR_WRITE_FAULT      = 29;
  ERROR_READ_FAULT       = 30;
  ERROR_HANDLE_EOF       = 38;
  ERROR_FILE_EXISTS      = 80;
  ERROR_INVALID_PARAMETER= 87;
  ERROR_BROKEN_PIPE      = 109;
  ERROR_NEGATIVE_SEEK    = 131;
  ERROR_DIR_NOT_EMPTY    = 145;
  ERROR_ALREADY_EXISTS   = 183;

  MAX_PATH = 1024;

  STD_INPUT_HANDLE  = DWORD(-10);
  STD_OUTPUT_HANDLE = DWORD(-11);
  STD_ERROR_HANDLE  = DWORD(-12);

  FOREGROUND_BLUE      = 1;
  FOREGROUND_GREEN     = 2;
  FOREGROUND_RED       = 4;
  FOREGROUND_INTENSITY = 8;
  BACKGROUND_BLUE      = $10;
  BACKGROUND_GREEN     = $20;
  BACKGROUND_RED       = $40;
  BACKGROUND_INTENSITY = $80;

  CP_ACP   = 0;
  CP_OEMCP = 1;
  CP_UTF8  = 65001;

  { Registry roots and ShowWindow constants: only used symbolically when
    reconstructing install scripts }
  HKEY_CLASSES_ROOT   = HKEY($80000000);
  HKEY_CURRENT_USER   = HKEY($80000001);
  HKEY_LOCAL_MACHINE  = HKEY($80000002);
  HKEY_USERS          = HKEY($80000003);
  HKEY_PERFORMANCE_DATA = HKEY($80000004);
  HKEY_CURRENT_CONFIG = HKEY($80000005);
  HKEY_DYN_DATA       = HKEY($80000006);

  SW_HIDE = 0;
  SW_SHOWNORMAL = 1;
  SW_SHOWMINIMIZED = 2;
  SW_SHOWMAXIMIZED = 3;
  SW_SHOWNOACTIVATE = 4;
  SW_SHOW = 5;
  SW_MINIMIZE = 6;
  SW_SHOWMINNOACTIVE = 7;
  SW_SHOWNA = 8;
  SW_RESTORE = 9;

  LOAD_LIBRARY_AS_DATAFILE = 2;

function GetLastError: DWORD;
procedure SetLastError(ErrorCode: DWORD);
function CloseHandle(h: THandle): BOOL;

function GetStdHandle(nStdHandle: DWORD): THandle;
function SetConsoleTextAttribute(hConsoleOutput: THandle; wAttributes: Word): BOOL;
function GetConsoleScreenBufferInfo(hConsoleOutput: THandle;
  var lpConsoleScreenBufferInfo: TConsoleScreenBufferInfo): BOOL;
function GetConsoleOutputCP: UINT;
function SetConsoleOutputCP(wCodePageID: UINT): BOOL;
function FileTimeToSystemTime(const lpFileTime: TFileTime; var lpSystemTime: TSystemTime): BOOL;
function SystemTimeToDateTime(const SystemTime: TSystemTime): TDateTime;
function WriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD;
  var lpNumberOfBytesWritten: DWORD; lpOverlapped: Pointer): BOOL;
function ReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; lpOverlapped: Pointer): BOOL;

function CreateDirectoryW(lpPathName: PWideChar; lpSecurityAttributes: Pointer): BOOL;
function CreateDirectory(lpPathName: PWideChar; lpSecurityAttributes: Pointer): BOOL;

{ FILETIME <-> Unix time helpers (Windows semantics preserved) }
function UnixTimeToFileTime(const ASecs: Int64; const ANanoSecs: Longint): TFileTime;
function FileTimeToUnixTime(const AFileTime: TFileTime; out ANanoSecs: Longint): Int64;
function SystemTimeToFileTime(const lpSystemTime: TSystemTime; var lpFileTime: TFileTime): BOOL;
function LocalFileTimeToFileTime(const lpLocalFileTime: TFileTime; var lpFileTime: TFileTime): BOOL;
function FileTimeToLocalFileTime(const lpFileTime: TFileTime; var lpLocalFileTime: TFileTime): BOOL;
function DosDateTimeToFileTime(wFatDate, wFatTime: Word; var lpFileTime: TFileTime): BOOL;
function SetFileTime(hFile: THandle; lpCreationTime, lpLastAccessTime,
  lpLastWriteTime: PFileTime): BOOL;

function GetFileAttributesW(lpFileName: PWideChar): DWORD;
function GetFileAttributes(lpFileName: PWideChar): DWORD;
function SetFileAttributesW(lpFileName: PWideChar; dwFileAttributes: DWORD): BOOL;
function SetFileAttributes(lpFileName: PWideChar; dwFileAttributes: DWORD): BOOL;

function LocalAlloc(uFlags: UINT; uBytes: PtrUInt): HLOCAL;
function LocalFree(hMem: HLOCAL): HLOCAL;

procedure CopyMemory(Destination, Source: Pointer; Length: PtrUInt);
procedure ZeroMemory(Destination: Pointer; Length: PtrUInt);
procedure FillMemory(Destination: Pointer; Length: PtrUInt; Fill: Byte);

const
  VER_PLATFORM_WIN32_NT = 2;
  Win32Platform = VER_PLATFORM_WIN32_NT;
  SM_DBCSENABLED = 42;

function CharToOemBuff(lpszSrc: PWideChar; lpszDst: PAnsiChar; cchDstLength: DWORD): BOOL;
function OemToCharBuff(lpszSrc: PAnsiChar; lpszDst: PWideChar; cchDstLength: DWORD): BOOL;
function IsDBCSLeadByte(TestChar: Byte): BOOL;
function GetSystemMetrics(nIndex: Integer): Integer;
function CharNext(lpsz: PWideChar): PWideChar;
function CharPrev(lpszStart, lpszCurrent: PWideChar): PWideChar;
function GetFullPathNameW(lpFileName: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; var lpFilePart: PWideChar): DWORD;
function GetFullPathName(lpFileName: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; var lpFilePart: PWideChar): DWORD;

const
  LMEM_FIXED = 0;

implementation

uses
  DateUtils, termio;

{ futimes is not surfaced by BaseUnix on Darwin }
function futimes(fd: cint; times: PTimeVal): cint; cdecl; external 'c' name 'futimes';

const
  { Difference between 1601-01-01 and 1970-01-01 in 100ns units }
  FILETIME_UNIX_DIFF = 116444736000000000;

threadvar
  LastError: DWORD;

function GetLastError: DWORD;
begin
  Result := LastError;
end;

procedure SetLastError(ErrorCode: DWORD);
begin
  LastError := ErrorCode;
end;

procedure CaptureErrno;
begin
  LastError := DWORD(fpgeterrno);
end;

function CloseHandle(h: THandle): BOOL;
begin
  Result := FpClose(cint(h)) = 0;
  if not Result then CaptureErrno;
end;

function GetStdHandle(nStdHandle: DWORD): THandle;
begin
  case nStdHandle of
    STD_INPUT_HANDLE:  Result := StdInputHandle;
    STD_OUTPUT_HANDLE: Result := StdOutputHandle;
    STD_ERROR_HANDLE:  Result := StdErrorHandle;
  else
    Result := INVALID_HANDLE_VALUE;
  end;
end;

function SetConsoleTextAttribute(hConsoleOutput: THandle; wAttributes: Word): BOOL;
const
  { Map the Win32 IRGB nibble to the ANSI color order (30 + BGR->RGB swap) }
  AnsiColor: array[0..7] of Byte = (0, 4, 2, 6, 1, 5, 3, 7);
var
  S: AnsiString;
  Fg, Bg: Byte;
begin
  Result := True;
  if IsATTY(cint(hConsoleOutput)) <> 1 then Exit;
  Fg := 30 + AnsiColor[wAttributes and 7];
  if wAttributes and FOREGROUND_INTENSITY <> 0 then Inc(Fg, 60);
  Bg := 40 + AnsiColor[(wAttributes shr 4) and 7];
  if wAttributes and BACKGROUND_INTENSITY <> 0 then Inc(Bg, 60);
  S := #27'[' + AnsiString(IntToStr(Fg)) + ';' + AnsiString(IntToStr(Bg)) + 'm';
  FpWrite(cint(hConsoleOutput), PAnsiChar(S)^, Length(S));
end;

function GetConsoleScreenBufferInfo(hConsoleOutput: THandle;
  var lpConsoleScreenBufferInfo: TConsoleScreenBufferInfo): BOOL;
begin
  { No Win32 console; the caller falls back to default colour attributes }
  Result := False;
end;

function GetConsoleOutputCP: UINT;
begin
  Result := CP_UTF8;
end;

function SetConsoleOutputCP(wCodePageID: UINT): BOOL;
begin
  { macOS terminals are UTF-8; nothing to switch }
  Result := True;
end;

function FileTimeToSystemTime(const lpFileTime: TFileTime; var lpSystemTime: TSystemTime): BOOL;
var
  Secs: Int64;
  NS: Longint;
  DT: TDateTime;
  DOW: Word;
begin
  Secs := FileTimeToUnixTime(lpFileTime, NS);
  DT := UnixToDateTime(Secs);  { treated as UTC, matching Win32 semantics }
  DecodeDate(DT, lpSystemTime.wYear, lpSystemTime.wMonth, lpSystemTime.wDay);
  DecodeTime(DT, lpSystemTime.wHour, lpSystemTime.wMinute, lpSystemTime.wSecond,
    lpSystemTime.wMilliseconds);
  DOW := DayOfWeek(DT);  { 1=Sunday..7=Saturday }
  lpSystemTime.wDayOfWeek := DOW - 1;  { Win32: 0=Sunday }
  Result := True;
end;

function SystemTimeToDateTime(const SystemTime: TSystemTime): TDateTime;
begin
  Result := EncodeDate(SystemTime.wYear, SystemTime.wMonth, SystemTime.wDay) +
    EncodeTime(SystemTime.wHour, SystemTime.wMinute, SystemTime.wSecond,
      SystemTime.wMilliseconds);
end;

function WriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD;
  var lpNumberOfBytesWritten: DWORD; lpOverlapped: Pointer): BOOL;
var
  Res: TsSize;
begin
  Res := FpWrite(cint(hFile), Buffer, nNumberOfBytesToWrite);
  if Res < 0 then begin
    lpNumberOfBytesWritten := 0;
    CaptureErrno;
    Result := False;
  end else begin
    lpNumberOfBytesWritten := DWORD(Res);
    Result := True;
  end;
end;

function ReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; lpOverlapped: Pointer): BOOL;
var
  Res: TsSize;
begin
  Res := FpRead(cint(hFile), Buffer, nNumberOfBytesToRead);
  if Res < 0 then begin
    lpNumberOfBytesRead := 0;
    CaptureErrno;
    Result := False;
  end else begin
    lpNumberOfBytesRead := DWORD(Res);
    Result := True;
  end;
end;

function CreateDirectoryW(lpPathName: PWideChar; lpSecurityAttributes: Pointer): BOOL;
var
  P: RawByteString;
begin
  P := Utf8Encode(UnicodeString(lpPathName));
  Result := FpMkdir(PAnsiChar(P), &755) = 0;
  if not Result then begin
    CaptureErrno;
    if fpgeterrno = ESysEEXIST then LastError := ERROR_ALREADY_EXISTS;
  end;
end;

function CreateDirectory(lpPathName: PWideChar; lpSecurityAttributes: Pointer): BOOL;
begin
  Result := CreateDirectoryW(lpPathName, lpSecurityAttributes);
end;

function UnixTimeToFileTime(const ASecs: Int64; const ANanoSecs: Longint): TFileTime;
var
  V: Int64;
begin
  V := ASecs * 10000000 + ANanoSecs div 100 + FILETIME_UNIX_DIFF;
  Result.dwLowDateTime := DWORD(V and $FFFFFFFF);
  Result.dwHighDateTime := DWORD(V shr 32);
end;

function FileTimeToUnixTime(const AFileTime: TFileTime; out ANanoSecs: Longint): Int64;
var
  V: Int64;
begin
  V := (Int64(AFileTime.dwHighDateTime) shl 32) or AFileTime.dwLowDateTime;
  Dec(V, FILETIME_UNIX_DIFF);
  Result := V div 10000000;
  ANanoSecs := (V mod 10000000) * 100;
  if ANanoSecs < 0 then begin
    Dec(Result);
    Inc(ANanoSecs, 1000000000);
  end;
end;

function SystemTimeToFileTime(const lpSystemTime: TSystemTime; var lpFileTime: TFileTime): BOOL;
var
  DT: TDateTime;
  US: Int64;
begin
  Result := TryEncodeDate(lpSystemTime.wYear, lpSystemTime.wMonth, lpSystemTime.wDay, DT);
  if not Result then Exit;
  { Seconds since Unix epoch, treating the input as UTC }
  US := (Trunc(DT) - 25569) * 86400
    + lpSystemTime.wHour * 3600 + lpSystemTime.wMinute * 60 + lpSystemTime.wSecond;
  lpFileTime := UnixTimeToFileTime(US, lpSystemTime.wMilliseconds * 1000000);
end;

function LocalFileTimeToFileTime(const lpLocalFileTime: TFileTime; var lpFileTime: TFileTime): BOOL;
var
  Secs: Int64;
  NS: Longint;
begin
  { Interpret the input as local wall-clock time and convert to UTC }
  Secs := FileTimeToUnixTime(lpLocalFileTime, NS);
  Secs := Secs + GetLocalTimeOffset * 60;
  lpFileTime := UnixTimeToFileTime(Secs, NS);
  Result := True;
end;

function FileTimeToLocalFileTime(const lpFileTime: TFileTime; var lpLocalFileTime: TFileTime): BOOL;
var
  Secs: Int64;
  NS: Longint;
begin
  Secs := FileTimeToUnixTime(lpFileTime, NS);
  Secs := Secs - GetLocalTimeOffset * 60;
  lpLocalFileTime := UnixTimeToFileTime(Secs, NS);
  Result := True;
end;

function DosDateTimeToFileTime(wFatDate, wFatTime: Word; var lpFileTime: TFileTime): BOOL;
var
  ST: TSystemTime;
begin
  ST.wYear := (wFatDate shr 9) + 1980;
  ST.wMonth := (wFatDate shr 5) and 15;
  ST.wDay := wFatDate and 31;
  ST.wHour := wFatTime shr 11;
  ST.wMinute := (wFatTime shr 5) and 63;
  ST.wSecond := (wFatTime and 31) * 2;
  ST.wMilliseconds := 0;
  Result := SystemTimeToFileTime(ST, lpFileTime);
end;

function SetFileTime(hFile: THandle; lpCreationTime, lpLastAccessTime,
  lpLastWriteTime: PFileTime): BOOL;
var
  TV: array[0..1] of TTimeVal;
  Secs: Int64;
  NS: Longint;
  Info: Stat;
begin
  Result := True;
  if lpLastWriteTime = nil then Exit;
  Secs := FileTimeToUnixTime(lpLastWriteTime^, NS);
  if lpLastAccessTime <> nil then begin
    TV[0].tv_sec := FileTimeToUnixTime(lpLastAccessTime^, NS);
    TV[0].tv_usec := NS div 1000;
  end else if FpFStat(cint(hFile), Info) = 0 then begin
    TV[0].tv_sec := Info.st_atime;
    TV[0].tv_usec := 0;
  end else begin
    TV[0].tv_sec := Secs;
    TV[0].tv_usec := 0;
  end;
  Secs := FileTimeToUnixTime(lpLastWriteTime^, NS);
  TV[1].tv_sec := Secs;
  TV[1].tv_usec := NS div 1000;
  Result := futimes(cint(hFile), @TV[0]) = 0;
  if not Result then CaptureErrno;
end;

function GetFileAttributesW(lpFileName: PWideChar): DWORD;
var
  P: RawByteString;
  Info: Stat;
begin
  P := Utf8Encode(UnicodeString(lpFileName));
  if FpStat(PAnsiChar(P), Info) <> 0 then begin
    CaptureErrno;
    Result := INVALID_FILE_ATTRIBUTES;
    Exit;
  end;
  Result := 0;
  if fpS_ISDIR(Info.st_mode) then
    Result := Result or FILE_ATTRIBUTE_DIRECTORY;
  if (Info.st_mode and S_IWUSR) = 0 then
    Result := Result or FILE_ATTRIBUTE_READONLY;
  if Result = 0 then
    Result := FILE_ATTRIBUTE_NORMAL;
end;

function GetFileAttributes(lpFileName: PWideChar): DWORD;
begin
  Result := GetFileAttributesW(lpFileName);
end;

function SetFileAttributesW(lpFileName: PWideChar; dwFileAttributes: DWORD): BOOL;
var
  P: RawByteString;
  Info: Stat;
  NewMode: TMode;
begin
  P := Utf8Encode(UnicodeString(lpFileName));
  if FpStat(PAnsiChar(P), Info) <> 0 then begin
    CaptureErrno;
    Result := False;
    Exit;
  end;
  if dwFileAttributes and FILE_ATTRIBUTE_READONLY <> 0 then
    NewMode := Info.st_mode and not (S_IWUSR or S_IWGRP or S_IWOTH)
  else
    NewMode := Info.st_mode or S_IWUSR;
  Result := FpChmod(PAnsiChar(P), NewMode) = 0;
  if not Result then CaptureErrno;
end;

function SetFileAttributes(lpFileName: PWideChar; dwFileAttributes: DWORD): BOOL;
begin
  Result := SetFileAttributesW(lpFileName, dwFileAttributes);
end;

function LocalAlloc(uFlags: UINT; uBytes: PtrUInt): HLOCAL;
begin
  Result := AllocMem(uBytes);
end;

function LocalFree(hMem: HLOCAL): HLOCAL;
begin
  FreeMem(hMem);
  Result := nil;
end;

procedure CopyMemory(Destination, Source: Pointer; Length: PtrUInt);
begin
  Move(Source^, Destination^, Length);
end;

procedure ZeroMemory(Destination: Pointer; Length: PtrUInt);
begin
  FillChar(Destination^, Length, 0);
end;

procedure FillMemory(Destination: Pointer; Length: PtrUInt; Fill: Byte);
begin
  FillChar(Destination^, Length, Fill);
end;

function CharToOemBuff(lpszSrc: PWideChar; lpszDst: PAnsiChar; cchDstLength: DWORD): BOOL;
var
  I: DWORD;
begin
  { Lossy ASCII conversion; UTF-8 output paths don't go through here }
  for I := 0 to cchDstLength - 1 do
    if Ord(lpszSrc[I]) < 128 then
      lpszDst[I] := AnsiChar(Ord(lpszSrc[I]))
    else
      lpszDst[I] := '?';
  Result := True;
end;

function OemToCharBuff(lpszSrc: PAnsiChar; lpszDst: PWideChar; cchDstLength: DWORD): BOOL;
var
  I: DWORD;
begin
  for I := 0 to cchDstLength - 1 do
    lpszDst[I] := WideChar(Ord(lpszSrc[I]));
  Result := True;
end;

function IsDBCSLeadByte(TestChar: Byte): BOOL;
begin
  Result := False;
end;

function GetSystemMetrics(nIndex: Integer): Integer;
begin
  Result := 0;
end;

function CharNext(lpsz: PWideChar): PWideChar;
begin
  Result := lpsz;
  if Result^ <> #0 then
    Inc(Result);
end;

function CharPrev(lpszStart, lpszCurrent: PWideChar): PWideChar;
begin
  if lpszCurrent > lpszStart then
    Result := lpszCurrent - 1
  else
    Result := lpszStart;
end;

function GetFullPathNameW(lpFileName: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; var lpFilePart: PWideChar): DWORD;
var
  Expanded: UnicodeString;
  I: Integer;
begin
  Expanded := ExpandFileName(UnicodeString(lpFileName));
  Result := Length(Expanded);
  if Result + 1 > nBufferLength then begin
    { Need a larger buffer: return required size including the terminator }
    Inc(Result);
    Exit;
  end;
  Move(PWideChar(Expanded)^, lpBuffer^, (Result + 1) * SizeOf(WideChar));
  lpFilePart := lpBuffer;
  for I := Result - 1 downto 0 do
    if lpBuffer[I] = '/' then begin
      lpFilePart := @lpBuffer[I + 1];
      Break;
    end;
end;

function GetFullPathName(lpFileName: PWideChar; nBufferLength: DWORD;
  lpBuffer: PWideChar; var lpFilePart: PWideChar): DWORD;
begin
  Result := GetFullPathNameW(lpFileName, nBufferLength, lpBuffer, lpFilePart);
end;

end.
