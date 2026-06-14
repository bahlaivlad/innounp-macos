unit PEResource;

{
  Minimal PE (Portable Executable) resource extractor for the macOS/FPC port
  of innounp. Replaces the LoadLibraryEx/FindResource/LoadResource chain used
  on Windows to read resources from setup loader executables. Supports PE32
  and PE32+ images, and numeric as well as named resources.
}

interface

{$MODE DELPHIUNICODE}

uses
  SysUtils, Classes;

const
  PE_RT_RCDATA = 10;

{ Reads the first language entry of resource (AResType, AResId) from the PE
  file AFileName. Returns False if the file is not a valid PE image or the
  resource does not exist. }
function LoadPEResource(const AFileName: String; const AResType, AResId: Cardinal;
  out Data: TBytes): Boolean;

{ Same, but for a named resource (e.g. 'PACKAGEINFO'). }
function LoadPEResourceNamed(const AFileName: String; const AResType: Cardinal;
  const AResName: UnicodeString; out Data: TBytes): Boolean;

implementation

type
  TSectionHeader = packed record
    Name: array[0..7] of AnsiChar;
    VirtualSize: Cardinal;
    VirtualAddress: Cardinal;
    SizeOfRawData: Cardinal;
    PointerToRawData: Cardinal;
    PointerToRelocations: Cardinal;
    PointerToLinenumbers: Cardinal;
    NumberOfRelocations: Word;
    NumberOfLinenumbers: Word;
    Characteristics: Cardinal;
  end;

  TResourceDirectory = packed record
    Characteristics: Cardinal;
    TimeDateStamp: Cardinal;
    MajorVersion: Word;
    MinorVersion: Word;
    NumberOfNamedEntries: Word;
    NumberOfIdEntries: Word;
  end;

  TResourceDirectoryEntry = packed record
    NameOrId: Cardinal;
    OffsetToData: Cardinal;  { high bit set: subdirectory }
  end;

  TResourceDataEntry = packed record
    DataRVA: Cardinal;
    Size: Cardinal;
    CodePage: Cardinal;
    Reserved: Cardinal;
  end;

function DoLoadPEResource(const AFileName: String; const AResType: Cardinal;
  const AResName: UnicodeString; const AResId: Cardinal; const ById: Boolean;
  out Data: TBytes): Boolean;
var
  F: TFileStream;
  Sections: array of TSectionHeader;

  function RvaToOffset(Rva: Cardinal; out Offset: Cardinal): Boolean;
  var
    I: Integer;
    Size: Cardinal;
  begin
    for I := 0 to High(Sections) do begin
      Size := Sections[I].VirtualSize;
      if Size = 0 then Size := Sections[I].SizeOfRawData;
      if (Rva >= Sections[I].VirtualAddress) and
         (Rva < Sections[I].VirtualAddress + Size) then begin
        Offset := Rva - Sections[I].VirtualAddress + Sections[I].PointerToRawData;
        Exit(True);
      end;
    end;
    Result := False;
  end;

  function ReadDirString(ResBase, StrOffset: Cardinal): UnicodeString;
  var
    Len: Word;
  begin
    Result := '';
    F.Position := Int64(ResBase) + StrOffset;
    if F.Read(Len, 2) <> 2 then Exit;
    SetLength(Result, Len);
    if Len > 0 then
      if F.Read(Result[1], Len * 2) <> Len * 2 then
        Result := '';
  end;

  { Returns the entry offset (relative to ResBase) for the wanted id or name
    within the directory at DirOffset (relative to ResBase), or 0 if not
    found. WantedId = High(Cardinal) matches the first id entry. }
  function FindDirEntry(ResBase, DirOffset: Cardinal; const WantedName: UnicodeString;
    WantedId: Cardinal; WantById: Boolean): Cardinal;
  var
    Dir: TResourceDirectory;
    Entries: array of TResourceDirectoryEntry;
    I, Total: Integer;
  begin
    Result := 0;
    F.Position := Int64(ResBase) + DirOffset;
    if F.Read(Dir, SizeOf(Dir)) <> SizeOf(Dir) then Exit;
    Total := Dir.NumberOfNamedEntries + Dir.NumberOfIdEntries;
    if Total = 0 then Exit;
    SetLength(Entries, Total);
    if F.Read(Entries[0], Total * SizeOf(TResourceDirectoryEntry)) <>
       Total * SizeOf(TResourceDirectoryEntry) then Exit;
    if WantById then begin
      for I := Dir.NumberOfNamedEntries to Total - 1 do
        if (WantedId = High(Cardinal)) or (Entries[I].NameOrId = WantedId) then
          Exit(Entries[I].OffsetToData);
    end
    else begin
      for I := 0 to Dir.NumberOfNamedEntries - 1 do
        if (Entries[I].NameOrId and $80000000 <> 0) and
           (CompareText(ReadDirString(ResBase, Entries[I].NameOrId and $7FFFFFFF),
             WantedName) = 0) then
          Exit(Entries[I].OffsetToData);
    end;
  end;

var
  ELfanew: Cardinal;
  Sig: Cardinal;
  Magic, NumSections, SizeOfOptional: Word;
  OptStart, DataDirOffset: Int64;
  ResRva, ResSize, ResBase: Cardinal;
  EntryOfs: Cardinal;
  DataEntry: TResourceDataEntry;
  DataOffset: Cardinal;
  I: Integer;
  W: Word;
begin
  Result := False;
  Data := nil;
  try
    F := TFileStream.Create(Utf8Encode(AFileName), fmOpenRead or fmShareDenyNone);
  except
    Exit;
  end;
  try
    { DOS header }
    if F.Read(W, 2) <> 2 then Exit;
    if W <> $5A4D then Exit;  { 'MZ' }
    F.Position := $3C;
    if F.Read(ELfanew, 4) <> 4 then Exit;
    F.Position := ELfanew;
    if (F.Read(Sig, 4) <> 4) or (Sig <> $00004550) then Exit;  { 'PE\0\0' }

    { COFF header }
    F.Position := F.Position + 2;  { Machine }
    if F.Read(NumSections, 2) <> 2 then Exit;
    F.Position := F.Position + 12; { TimeDateStamp, PointerToSymbolTable, NumberOfSymbols }
    if F.Read(SizeOfOptional, 2) <> 2 then Exit;
    F.Position := F.Position + 2;  { Characteristics }

    { Optional header: data directory 2 is the resource table }
    OptStart := F.Position;
    if F.Read(Magic, 2) <> 2 then Exit;
    case Magic of
      $10B: DataDirOffset := OptStart + 96 + 2 * 8;   { PE32 }
      $20B: DataDirOffset := OptStart + 112 + 2 * 8;  { PE32+ }
    else
      Exit;
    end;
    F.Position := DataDirOffset;
    if (F.Read(ResRva, 4) <> 4) or (F.Read(ResSize, 4) <> 4) then Exit;
    if (ResRva = 0) or (ResSize = 0) then Exit;

    { Section table }
    SetLength(Sections, NumSections);
    F.Position := OptStart + SizeOfOptional;
    for I := 0 to NumSections - 1 do
      if F.Read(Sections[I], SizeOf(TSectionHeader)) <> SizeOf(TSectionHeader) then
        Exit;

    if not RvaToOffset(ResRva, ResBase) then Exit;

    { Walk type -> name/id -> language }
    EntryOfs := FindDirEntry(ResBase, 0, '', AResType, True);
    if EntryOfs and $80000000 = 0 then Exit;
    EntryOfs := FindDirEntry(ResBase, EntryOfs and $7FFFFFFF, AResName, AResId, ById);
    if EntryOfs and $80000000 = 0 then Exit;
    EntryOfs := FindDirEntry(ResBase, EntryOfs and $7FFFFFFF, '', High(Cardinal), True);
    if EntryOfs and $80000000 <> 0 then Exit;  { expected a data entry }
    if EntryOfs = 0 then Exit;

    F.Position := Int64(ResBase) + EntryOfs;
    if F.Read(DataEntry, SizeOf(DataEntry)) <> SizeOf(DataEntry) then Exit;
    if not RvaToOffset(DataEntry.DataRVA, DataOffset) then Exit;

    SetLength(Data, DataEntry.Size);
    F.Position := DataOffset;
    if F.Read(Data[0], DataEntry.Size) <> Integer(DataEntry.Size) then Exit;
    Result := True;
  finally
    F.Free;
  end;
end;

function LoadPEResource(const AFileName: String; const AResType, AResId: Cardinal;
  out Data: TBytes): Boolean;
begin
  Result := DoLoadPEResource(AFileName, AResType, '', AResId, True, Data);
end;

function LoadPEResourceNamed(const AFileName: String; const AResType: Cardinal;
  const AResName: UnicodeString; out Data: TBytes): Boolean;
begin
  Result := DoLoadPEResource(AFileName, AResType, AResName, 0, False, Data);
end;

end.
