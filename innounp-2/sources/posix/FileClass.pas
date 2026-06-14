unit FileClass;

{
  Inno Setup
  Copyright (C) 1997-2024 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  TFile class
  POSIX implementation for the macOS/FPC port of innounp.
  The public interface matches the original Win32 unit; handles are
  POSIX file descriptors.

  TTextFileReader and TTextFileWriter support ANSI and UTF8 textfiles.
}

interface

{$MODE DELPHIUNICODE}

uses
  Winapi.Windows, SysUtils, Int64Em;

type
  TFileCreateDisposition = (fdCreateAlways, fdCreateNew, fdOpenExisting,
    fdOpenAlways, fdTruncateExisting);
  TFileAccess = (faRead, faWrite, faReadWrite);
  TFileSharing = (fsNone, fsRead, fsWrite, fsReadWrite);

  TCustomFile = class
  private
    function GetCappedSize: Cardinal;
  protected
    function GetPosition: Integer64; virtual; abstract;
    function GetSize: Integer64; virtual; abstract;
  public
    class procedure RaiseError(ErrorCode: DWORD);
    class procedure RaiseLastError;
    function Read(var Buffer; Count: Cardinal): Cardinal; virtual; abstract;
    procedure ReadBuffer(var Buffer; Count: Cardinal);
    procedure Seek(Offset: Cardinal);
    procedure Seek64(Offset: Integer64); virtual; abstract;
    procedure WriteAnsiString(const S: AnsiString);
    procedure WriteBuffer(const Buffer; Count: Cardinal); virtual; abstract;
    property CappedSize: Cardinal read GetCappedSize;
    property Position: Integer64 read GetPosition;
    property Size: Integer64 read GetSize;
  end;

  TFile = class(TCustomFile)
  private
    FHandle: THandle;
    FHandleCreated: Boolean;
  protected
    function CreateHandle(const AFilename: String;
      ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
      ASharing: TFileSharing): THandle; virtual;
    function GetPosition: Integer64; override;
    function GetSize: Integer64; override;
  public
    constructor Create(const AFilename: String;
      ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
      ASharing: TFileSharing);
    constructor CreateWithExistingHandle(const AHandle: THandle);
    destructor Destroy; override;
    function Read(var Buffer; Count: Cardinal): Cardinal; override;
    procedure Seek64(Offset: Integer64); override;
    procedure SeekToEnd;
    procedure Truncate; virtual;
    procedure WriteBuffer(const Buffer; Count: Cardinal); override;
    property Handle: THandle read FHandle;
  end;

  TMemoryFile = class(TCustomFile)
  private
    FMemory: Pointer;
    FSize: Integer64;
    FPosition: Integer64;
    function ClipCount(DesiredCount: Cardinal): Cardinal;
  protected
    procedure AllocMemory(const ASize: Cardinal);
    function GetPosition: Integer64; override;
    function GetSize: Integer64; override;
  public
    constructor Create(const AFilename: String);
    constructor CreateFromMemory(const ASource; const ASize: Cardinal);
    constructor CreateFromZero(const ASize: Cardinal);
    destructor Destroy; override;
    function Read(var Buffer; Count: Cardinal): Cardinal; override;
    procedure Seek64(Offset: Integer64); override;
    procedure WriteBuffer(const Buffer; Count: Cardinal); override;
    property Memory: Pointer read FMemory;
  end;

  TTextFileReader = class(TFile)
  private
    FBufferOffset, FBufferSize: Cardinal;
    FEof: Boolean;
    FBuffer: array[0..4095] of AnsiChar;
    FSawFirstLine: Boolean;
    FCodePage: Cardinal;
    function DoReadLine(const UTF8: Boolean): AnsiString;
    function GetEof: Boolean;
    procedure FillBuffer;
  public
    function ReadLine: String;
    function ReadAnsiLine: AnsiString;
    property CodePage: Cardinal write FCodePage;
    property Eof: Boolean read GetEof;
  end;

  TTextFileWriter = class(TFile)
  private
    FSeekedToEnd: Boolean;
    FUTF8WithoutBOM: Boolean;
    procedure DoWrite(const S: AnsiString; const UTF8: Boolean);
  protected
    function CreateHandle(const AFilename: String;
      ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
      ASharing: TFileSharing): THandle; override;
  public
    property UTF8WithoutBOM: Boolean read FUTF8WithoutBOM write FUTF8WithoutBOM;
    procedure Write(const S: String);
    procedure WriteLine(const S: String);
    procedure WriteAnsi(const S: AnsiString);
    procedure WriteAnsiLine(const S: AnsiString);
  end;

  EFileError = class(Exception)
  private
    FErrorCode: DWORD;
  public
    property ErrorCode: DWORD read FErrorCode;
  end;

implementation

uses
  BaseUnix, WideStrUtils, CmnFunc2;

const
  SGenericIOError = 'File I/O error %d';

function Int64ToInteger64(const V: Int64): Integer64;
begin
  Result.Lo := LongWord(V and $FFFFFFFF);
  Result.Hi := LongWord(V shr 32);
end;

function Integer64ToInt64(const V: Integer64): Int64;
begin
  Result := (Int64(V.Hi) shl 32) or V.Lo;
end;

{ TCustomFile }

function TCustomFile.GetCappedSize: Cardinal;
{ Like GetSize, but capped at $7FFFFFFF }
var
  S: Integer64;
begin
  S := GetSize;
  if (S.Hi = 0) and (S.Lo and $80000000 = 0) then
    Result := S.Lo
  else
    Result := $7FFFFFFF;
end;

class procedure TCustomFile.RaiseError(ErrorCode: DWORD);
var
  S: String;
  E: EFileError;
begin
  { Explicitly raised Win32 codes get fixed messages; everything else is
    treated as errno (see RaiseLastError). }
  case ErrorCode of
    ERROR_HANDLE_EOF:    S := 'Reached the end of the file';
    ERROR_WRITE_FAULT:   S := 'The system cannot write to the specified device';
    ERROR_READ_FAULT:    S := 'The system cannot read from the specified device';
    ERROR_NEGATIVE_SEEK: S := 'An attempt was made to move the file pointer before the beginning of the file';
  else
    S := Win32ErrorString(ErrorCode);
  end;
  if S = '' then
    S := Format(SGenericIOError, [ErrorCode]);
  E := EFileError.Create(S);
  E.FErrorCode := ErrorCode;
  raise E;
end;

class procedure TCustomFile.RaiseLastError;
begin
  RaiseError(GetLastError);
end;

procedure TCustomFile.ReadBuffer(var Buffer; Count: Cardinal);
begin
  if Read(Buffer, Count) <> Count then begin
    { Raise localized "Reached end of file" error }
    RaiseError(ERROR_HANDLE_EOF);
  end;
end;

procedure TCustomFile.Seek(Offset: Cardinal);
var
  I: Integer64;
begin
  I.Hi := 0;
  I.Lo := Offset;
  Seek64(I);
end;

procedure TCustomFile.WriteAnsiString(const S: AnsiString);
begin
  WriteBuffer(S[1], Length(S));
end;

{ TFile }

constructor TFile.Create(const AFilename: String;
  ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
  ASharing: TFileSharing);
begin
  inherited Create;
  FHandle := CreateHandle(AFilename, ACreateDisposition, AAccess, ASharing);
  if FHandle = INVALID_HANDLE_VALUE then
    RaiseLastError;
  FHandleCreated := True;
end;

constructor TFile.CreateWithExistingHandle(const AHandle: THandle);
begin
  inherited Create;
  FHandle := AHandle;
end;

destructor TFile.Destroy;
begin
  if FHandleCreated then
    CloseHandle(FHandle);
  inherited;
end;

function TFile.CreateHandle(const AFilename: String;
  ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
  ASharing: TFileSharing): THandle;
const
  AccessFlags: array[TFileAccess] of cint = (O_RDONLY, O_WRONLY, O_RDWR);
  Disps: array[TFileCreateDisposition] of cint =
    (O_CREAT or O_TRUNC, O_CREAT or O_EXCL, 0, O_CREAT, O_TRUNC);
var
  P: RawByteString;
  FD: cint;
begin
  P := Utf8Encode(AFilename);
  repeat
    FD := FpOpen(PAnsiChar(P), AccessFlags[AAccess] or Disps[ACreateDisposition],
      &644);
  until (FD >= 0) or (fpgeterrno <> ESysEINTR);
  if FD < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    Result := INVALID_HANDLE_VALUE;
  end
  else
    Result := THandle(FD);
end;

function TFile.GetPosition: Integer64;
var
  Pos: TOff;
begin
  Pos := FpLseek(cint(FHandle), 0, SEEK_CUR);
  if Pos < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
  Result := Int64ToInteger64(Pos);
end;

function TFile.GetSize: Integer64;
var
  Info: Stat;
begin
  if FpFStat(cint(FHandle), Info) <> 0 then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
  Result := Int64ToInteger64(Info.st_size);
end;

function TFile.Read(var Buffer; Count: Cardinal): Cardinal;
var
  Res: TsSize;
begin
  repeat
    Res := FpRead(cint(FHandle), Buffer, Count);
  until (Res >= 0) or (fpgeterrno <> ESysEINTR);
  if Res < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    if FHandleCreated or (fpgeterrno <> ESysEPIPE) then
      RaiseLastError;
    Res := 0;
  end;
  Result := Cardinal(Res);
end;

procedure TFile.Seek64(Offset: Integer64);
begin
  if FpLseek(cint(FHandle), Integer64ToInt64(Offset), SEEK_SET) < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
end;

procedure TFile.SeekToEnd;
begin
  if FpLseek(cint(FHandle), 0, SEEK_END) < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
end;

procedure TFile.Truncate;
var
  Pos: TOff;
begin
  { Win32 SetEndOfFile truncates at the current file pointer }
  Pos := FpLseek(cint(FHandle), 0, SEEK_CUR);
  if (Pos < 0) or (FpFtruncate(cint(FHandle), Pos) <> 0) then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
end;

procedure TFile.WriteBuffer(const Buffer; Count: Cardinal);
var
  Res: TsSize;
begin
  repeat
    Res := FpWrite(cint(FHandle), Buffer, Count);
  until (Res >= 0) or (fpgeterrno <> ESysEINTR);
  if Res < 0 then begin
    SetLastError(DWORD(fpgeterrno));
    RaiseLastError;
  end;
  if Cardinal(Res) <> Count then
    RaiseError(ERROR_WRITE_FAULT);
end;

{ TMemoryFile }

constructor TMemoryFile.Create(const AFilename: String);
var
  F: TFile;
begin
  inherited Create;
  F := TFile.Create(AFilename, fdOpenExisting, faRead, fsRead);
  try
    AllocMemory(F.CappedSize);
    F.ReadBuffer(FMemory^, FSize.Lo);
  finally
    F.Free;
  end;
end;

constructor TMemoryFile.CreateFromMemory(const ASource; const ASize: Cardinal);
begin
  inherited Create;
  AllocMemory(ASize);
  Move(ASource, FMemory^, FSize.Lo);
end;

constructor TMemoryFile.CreateFromZero(const ASize: Cardinal);
begin
  inherited Create;
  AllocMemory(ASize);
  FillChar(FMemory^, FSize.Lo, 0);
end;

destructor TMemoryFile.Destroy;
begin
  if Assigned(FMemory) then
    FreeMem(FMemory);
  inherited;
end;

procedure TMemoryFile.AllocMemory(const ASize: Cardinal);
begin
  FMemory := AllocMem(ASize);
  if FMemory = nil then
    OutOfMemoryError;
  FSize.Lo := ASize;
end;

function TMemoryFile.ClipCount(DesiredCount: Cardinal): Cardinal;
var
  BytesLeft: Integer64;
begin
  { First check if FPosition is already past FSize, so the Dec6464 call below
    won't underflow }
  if Compare64(FPosition, FSize) >= 0 then begin
    Result := 0;
    Exit;
  end;
  BytesLeft := FSize;
  Dec6464(BytesLeft, FPosition);
  if (BytesLeft.Hi = 0) and (BytesLeft.Lo < DesiredCount) then
    Result := BytesLeft.Lo
  else
    Result := DesiredCount;
end;

function TMemoryFile.GetPosition: Integer64;
begin
  Result := FPosition;
end;

function TMemoryFile.GetSize: Integer64;
begin
  Result := FSize;
end;

function TMemoryFile.Read(var Buffer; Count: Cardinal): Cardinal;
begin
  Result := ClipCount(Count);
  if Result <> 0 then begin
    Move(Pointer(PtrUInt(FMemory) + FPosition.Lo)^, Buffer, Result);
    Inc64(FPosition, Result);
  end;
end;

procedure TMemoryFile.Seek64(Offset: Integer64);
begin
  if Offset.Hi and $80000000 <> 0 then
    RaiseError(ERROR_NEGATIVE_SEEK);
  FPosition := Offset;
end;

procedure TMemoryFile.WriteBuffer(const Buffer; Count: Cardinal);
begin
  if ClipCount(Count) <> Count then
    RaiseError(ERROR_HANDLE_EOF);
  if Count <> 0 then begin
    Move(Buffer, Pointer(PtrUInt(FMemory) + FPosition.Lo)^, Count);
    Inc64(FPosition, Count);
  end;
end;

{ TTextFileReader }

procedure TTextFileReader.FillBuffer;
begin
  if (FBufferOffset < FBufferSize) or FEof then
    Exit;
  FBufferSize := Read(FBuffer, SizeOf(FBuffer));
  FBufferOffset := 0;
  if FBufferSize = 0 then
    FEof := True;
end;

function TTextFileReader.GetEof: Boolean;
begin
  FillBuffer;
  Result := FEof;
end;

function TTextFileReader.ReadLine: String;
var
 S: RawByteString;
begin
 S := DoReadLine(True);
 if FCodePage <> 0 then
   SetCodePage(S, FCodePage, False);
 Result := String(S);
end;

function TTextFileReader.ReadAnsiLine: AnsiString;
begin
  Result := DoReadLine(False);
end;

function TTextFileReader.DoReadLine(const UTF8: Boolean): AnsiString;
var
  I, L: Cardinal;
  S: AnsiString;
  OldPosition : integer64;
  CappedSize : cardinal;
  S2: AnsiString;
begin
  while True do begin
    FillBuffer;
    if FEof then begin
      { End of file reached }
      if S = '' then begin
        { If nothing was read (i.e. we were already at EOF), raise localized
          "Reached end of file" error }
        RaiseError(ERROR_HANDLE_EOF);
      end;
      Break;
    end;

    I := FBufferOffset;
    while I < FBufferSize do begin
      if FBuffer[I] in [#10, #13] then
        Break;
      Inc(I);
    end;
    L := Length(S);
    if Integer(L + (I - FBufferOffset)) < 0 then
      OutOfMemoryError;
    SetLength(S, L + (I - FBufferOffset));
    Move(FBuffer[FBufferOffset], S[L+1], I - FBufferOffset);
    FBufferOffset := I;

    if FBufferOffset < FBufferSize then begin
      { End of line reached }
      Inc(FBufferOffset);
      if FBuffer[FBufferOffset-1] = #13 then begin
        { Skip #10 if it follows #13 }
        FillBuffer;
        if (FBufferOffset < FBufferSize) and (FBuffer[FBufferOffset] = #10) then
          Inc(FBufferOffset);
      end;
      Break;
    end;
  end;

  if not FSawFirstLine then begin
    if UTF8 then begin
      { Handle UTF8 as requested: check for a BOM at the start and if not found then check entire file }
      if (Length(S) > 2) and (S[1] = #$EF) and (S[2] = #$BB) and (S[3] = #$BF) then begin
        Delete(S, 1, 3);
        FCodePage := CP_UTF8;
      end else begin
        OldPosition := GetPosition;
        try
          CappedSize := GetCappedSize; //can't be 0
          Seek(0);
          SetLength(S2, CappedSize);
          SetLength(S2, Read(S2[1], CappedSize));
          if DetectUTF8Encoding(S2) in [etUSASCII, etUTF8] then
            FCodePage := CP_UTF8;
        finally
          Seek64(OldPosition);
        end;
      end;
    end;
    FSawFirstLine := True;
  end;

  Result := S;
end;

{ TTextFileWriter }

function TTextFileWriter.CreateHandle(const AFilename: String;
  ACreateDisposition: TFileCreateDisposition; AAccess: TFileAccess;
  ASharing: TFileSharing): THandle;
begin
  { faWrite access isn't enough; we need faReadWrite access since the Write
    method may read. No, we don't have to do this automatically, but it helps
    keep it from being a 'leaky abstraction'. }
  if AAccess = faWrite then
    AAccess := faReadWrite;
  Result := inherited CreateHandle(AFilename, ACreateDisposition, AAccess,
    ASharing);
end;

procedure TTextFileWriter.DoWrite(const S: AnsiString; const UTF8: Boolean);
{ Writes a string to the file, seeking to the end first if necessary }
const
  CRLF: array[0..1] of AnsiChar = (#13, #10);
  UTF8BOM: array[0..2] of AnsiChar = (#$EF, #$BB, #$BF);
var
  I: Integer64;
  C: AnsiChar;
begin
  if not FSeekedToEnd then begin
    I := GetSize;
    if (I.Lo <> 0) or (I.Hi <> 0) then begin
      { File is not empty. Figure out if we have to append a line break. }
      Dec64(I, SizeOf(C));
      Seek64(I);
      ReadBuffer(C, SizeOf(C));
      case C of
        #10: ;  { do nothing - file ends in LF or CRLF }
        #13: begin
            { If the file ends in CR, make it into CRLF }
            C := #10;
            WriteBuffer(C, SizeOf(C));
          end;
      else
        { Otherwise, append CRLF }
        WriteBuffer(CRLF, SizeOf(CRLF));
      end;
    end else if UTF8 and not FUTF8WithoutBOM then
      WriteBuffer(UTF8BOM, SizeOf(UTF8BOM));
    FSeekedToEnd := True;
  end;
  WriteBuffer(Pointer(S)^, Length(S));
end;

procedure TTextFileWriter.Write(const S: String);
begin
  DoWrite(Utf8Encode(S), True);
end;

procedure TTextFileWriter.WriteLine(const S: String);
begin
  Write(S + #13#10);
end;

procedure TTextFileWriter.WriteAnsi(const S: AnsiString);
begin
  DoWrite(S, False);
end;

procedure TTextFileWriter.WriteAnsiLine(const S: AnsiString);
begin
  WriteAnsi(S + #13#10);
end;

end.
