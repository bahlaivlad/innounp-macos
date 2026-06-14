unit bzlib;

{
  Inno Setup
  Copyright (C) 1997-2004 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  Declarations for some bzlib2 functions & structures

  $jrsoftware: issrc/Projects/bzlib.pas,v 1.10 2004/02/17 09:29:49 jr Exp $
}

interface

uses
  SysUtils, Compress;

function BZInitCompressFunctions(Module: PtrUInt): Boolean;
function BZInitDecompressFunctions(Module: PtrUInt): Boolean;

type
  TBZAlloc = function(AppData: Pointer; Items, Size: Integer): Pointer; cdecl;
  TBZFree = procedure(AppData, Block: Pointer); cdecl;
  { Matches the C bz_stream layout on LP64 (macOS arm64) }
{$PACKRECORDS C}
  TBZStreamRec = record
    next_in: PByte;
    avail_in: Cardinal;
    total_in: Cardinal;
    total_in_hi: Cardinal;

    next_out: PByte;
    avail_out: Cardinal;
    total_out: Cardinal;
    total_out_hi: Cardinal;

    State: Pointer;

    zalloc: TBZAlloc;
    zfree: TBZFree;
    AppData: Pointer;
  end;
{$PACKRECORDS DEFAULT}

  TBZDecompressor = class(TCustomDecompressor)
  private
    FInitialized: Boolean;
    FStrm: TBZStreamRec;
    FReachedEnd: Boolean;
    FBuffer: array[0..65535] of Byte;
    FHeapBase, FHeapNextFree: Pointer;
    function Malloc(Bytes: Cardinal): Pointer;
  public
    constructor Create(AReadProc: TDecompressorReadProc); override;
    destructor Destroy; override;
    procedure DecompressInto(var Buffer; Count: Longint); override;
    procedure Reset; override;
  end;

  function BZ2_bzDecompressInit(var strm: TBZStreamRec;
    verbosity, small: Integer): Integer; cdecl;
  function BZ2_bzDecompress(var strm: TBZStreamRec): Integer; cdecl;
  function BZ2_bzDecompressEnd(var strm: TBZStreamRec): Integer; cdecl;

implementation

{ macOS/FPC port: the statically linked x86 bzip2 objects were replaced by
  calls into the system libbz2 library. }

const
{$LINKLIB bz2}
  libbz2 = 'bz2';

  function BZ2_bzDecompressInit(var strm: TBZStreamRec;
    verbosity, small: Integer): Integer; cdecl; external libbz2 name 'BZ2_bzDecompressInit';
  function BZ2_bzDecompress(var strm: TBZStreamRec): Integer; cdecl; external libbz2 name 'BZ2_bzDecompress';
  function BZ2_bzDecompressEnd(var strm: TBZStreamRec): Integer; cdecl; external libbz2 name 'BZ2_bzDecompressEnd';

{  BZ2_bzDecompressInit: function(var strm: TBZStreamRec;
    verbosity, small: Integer): Integer; stdcall;
  BZ2_bzDecompress: function(var strm: TBZStreamRec): Integer; stdcall;
  BZ2_bzDecompressEnd: function(var strm: TBZStreamRec): Integer; stdcall;}

const
  BZ_RUN              = 0;
  BZ_FLUSH            = 1;
  BZ_FINISH           = 2;

  BZ_OK               = 0;
  BZ_RUN_OK           = 1;
  BZ_FLUSH_OK         = 2;
  BZ_FINISH_OK        = 3;
  BZ_STREAM_END       = 4;
  BZ_SEQUENCE_ERROR   = (-1);
  BZ_PARAM_ERROR      = (-2);
  BZ_MEM_ERROR        = (-3);
  BZ_DATA_ERROR       = (-4);
  BZ_DATA_ERROR_MAGIC = (-5);
  BZ_IO_ERROR         = (-6);
  BZ_UNEXPECTED_EOF   = (-7);
  BZ_OUTBUFF_FULL     = (-8);
  BZ_CONFIG_ERROR     = (-9);

  SBzlibDataError = 'bzlib: Compressed data is corrupted';
  SBzlibInternalError = 'bzlib: Internal error. Code %d';
  SBzlibAllocError = 'bzlib: Too much memory requested';


function BZInitCompressFunctions(Module: PtrUInt): Boolean;
begin
  { Compression is not used by innounp }
  Result := False;
end;

function BZInitDecompressFunctions(Module: PtrUInt): Boolean;
begin
{  BZ2_bzDecompressInit := GetProcAddress(Module, 'BZ2_bzDecompressInit');
  BZ2_bzDecompress := GetProcAddress(Module, 'BZ2_bzDecompress');
  BZ2_bzDecompressEnd := GetProcAddress(Module, 'BZ2_bzDecompressEnd');
  Result := Assigned(BZ2_bzDecompressInit) and Assigned(BZ2_bzDecompress) and
    Assigned(BZ2_bzDecompressEnd);
  if not Result then begin
    BZ2_bzDecompressInit := nil;
    BZ2_bzDecompress := nil;
    BZ2_bzDecompressEnd := nil;
  end;}
  Result:=true;
end;

function BZAllocMem(AppData: Pointer; Items, Size: Integer): Pointer; cdecl;
begin
  try
    GetMem(Result, Items * Size);
  except
    { trap any exception, because zlib expects a NULL result if it's out
      of memory }
    Result := nil;
  end;
end;

procedure BZFreeMem(AppData, Block: Pointer); cdecl;
begin
  FreeMem(Block);
end;

function Check(const Code: Integer; const ValidCodes: array of Integer): Integer;
var
  I: Integer;
begin
  if Code = BZ_MEM_ERROR then
    OutOfMemoryError;
  Result := Code;
  for I := Low(ValidCodes) to High(ValidCodes) do
    if ValidCodes[I] = Code then
      Exit;
  raise ECompressInternalError.CreateFmt(SBzlibInternalError, [Code]);
end;

procedure InitStream(var strm: TBZStreamRec);
begin
  FillChar(strm, SizeOf(strm), 0);
  with strm do begin
    zalloc := BZAllocMem;
    zfree := BZFreeMem;
  end;
end;

{ TBZDecompressor }

{ Why does TBZDecompressor use VirtualAlloc instead of GetMem?
  It IS 4.0.1 it did use GetMem and allocate blocks on demand, but thanks to
  Delphi's flawed memory manager this resulted in crippling memory
  fragmentation when Reset was called repeatedly (e.g. when an installation
  contained thousands of files and solid decompression was disabled) while
  Setup was allocating other small blocks (e.g. FileLocationFilenames[]), and
  eventually caused Setup to run out of virtual address space.
  So, it was changed to allocate only one chunk of virtual address space for
  the entire lifetime of the TBZDecompressor instance. It divides this chunk
  into smaller amounts as requested by bzlib. As IS only creates one instance
  of TBZDecompressor, this change should completely eliminate the
  fragmentation issue. }

const
  DecompressorHeapSize = $600000;
  { 6 MB should be more than enough; the most I've seen bzlib 1.0.2's
    bzDecompress* allocate is 64116 + 3600000 bytes, when decompressing data
    compressed at level 9 }

function DecompressorAllocMem(AppData: Pointer; Items, Size: Integer): Pointer; cdecl;
begin
  Result := TBZDecompressor(AppData).Malloc(Cardinal(Items) * Cardinal(Size));
end;

procedure DecompressorFreeMem(AppData, Block: Pointer); cdecl;
begin
  { Since bzlib doesn't repeatedly deallocate and allocate blocks during a
    decompression run, we don't have to handle frees. }
end;

constructor TBZDecompressor.Create(AReadProc: TDecompressorReadProc);
begin
  inherited Create(AReadProc);
  { POSIX port: plain allocation instead of the VirtualAlloc reserve/commit
    scheme (the fragmentation workaround it implemented is Win32-specific) }
  FHeapBase := GetMem(DecompressorHeapSize);
  if FHeapBase = nil then
    OutOfMemoryError;
  FHeapNextFree := FHeapBase;
  FStrm.AppData := Self;
  FStrm.zalloc := DecompressorAllocMem;
  FStrm.zfree := DecompressorFreeMem;
  FStrm.next_in := @FBuffer;
  FStrm.avail_in := 0;
  Check(BZ2_bzDecompressInit(FStrm, 0, 0), [BZ_OK]);
  FInitialized := True;
end;

destructor TBZDecompressor.Destroy;
begin
  if FInitialized then
    BZ2_bzDecompressEnd(FStrm);
  if Assigned(FHeapBase) then
    FreeMem(FHeapBase);
  inherited Destroy;
end;

function TBZDecompressor.Malloc(Bytes: Cardinal): Pointer;
begin
  { Round up to dword boundary if necessary }
  if Bytes mod 4 <> 0 then
    Inc(Bytes, 4 - Bytes mod 4);

  { Did bzlib request more memory than we reserved? This shouldn't happen
    unless this unit is used with a different version of bzlib that allocates
    more memory. Note: The funky Cardinal casts are there to convince
    Delphi (2) to do an unsigned compare. }
  if PtrUInt(PtrUInt(FHeapNextFree) - PtrUInt(FHeapBase) + Bytes) > Cardinal(DecompressorHeapSize) then
    raise ECompressInternalError.Create(SBzlibAllocError);

  Result := FHeapNextFree;
  Inc(PByte(FHeapNextFree), Bytes);
end;

procedure TBZDecompressor.DecompressInto(var Buffer; Count: Longint);
begin
  FStrm.next_out := @Buffer;
  FStrm.avail_out := Count;
  while FStrm.avail_out > 0 do begin
    if FReachedEnd then  { unexpected EOF }
      raise ECompressDataError.Create(SBzlibDataError);
    if FStrm.avail_in = 0 then begin
      FStrm.next_in := @FBuffer;
      FStrm.avail_in := ReadProc(FBuffer, SizeOf(FBuffer));
      { Unlike zlib, bzlib does not return an error when avail_in is zero and
        it still needs input. To avoid an infinite loop, check for this and
        consider it a data error. }
      if FStrm.avail_in = 0 then
        raise ECompressDataError.Create(SBzlibDataError);
    end;
    case Check(BZ2_bzDecompress(FStrm), [BZ_OK, BZ_STREAM_END, BZ_DATA_ERROR, BZ_DATA_ERROR_MAGIC]) of
      BZ_STREAM_END: FReachedEnd := True;
      BZ_DATA_ERROR, BZ_DATA_ERROR_MAGIC: raise ECompressDataError.Create(SBzlibDataError);
    end;
  end;
end;

procedure TBZDecompressor.Reset;
begin
  FStrm.next_in := @FBuffer;
  FStrm.avail_in := 0;
  { bzlib doesn't offer an optimized 'Reset' function like zlib }
  BZ2_bzDecompressEnd(FStrm);
  FHeapNextFree := FHeapBase;  { discard previous allocations }
  Check(BZ2_bzDecompressInit(FStrm, 0, 0), [BZ_OK]);
  FReachedEnd := False;
end;

end.
