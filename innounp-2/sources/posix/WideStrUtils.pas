unit WideStrUtils;

{
  Minimal replacement for the Delphi WideStrUtils unit (macOS/FPC port of
  innounp): only DetectUTF8Encoding and the related types are provided.
}

interface

{$MODE DELPHIUNICODE}

type
  TEncodeType = (etUSASCII, etUTF8, etANSI);

function DetectUTF8Encoding(const S: RawByteString): TEncodeType;

implementation

function DetectUTF8Encoding(const S: RawByteString): TEncodeType;
var
  I, L, Follow: Integer;
  B: Byte;
  SeenNonAscii: Boolean;
begin
  L := Length(S);
  SeenNonAscii := False;
  I := 1;
  while I <= L do begin
    B := Byte(S[I]);
    if B < $80 then
      Inc(I)
    else begin
      SeenNonAscii := True;
      if (B and $E0) = $C0 then Follow := 1
      else if (B and $F0) = $E0 then Follow := 2
      else if (B and $F8) = $F0 then Follow := 3
      else Exit(etANSI);
      if I + Follow > L then Exit(etANSI);
      while Follow > 0 do begin
        Inc(I);
        if (Byte(S[I]) and $C0) <> $80 then Exit(etANSI);
        Dec(Follow);
      end;
      Inc(I);
    end;
  end;
  if SeenNonAscii then
    Result := etUTF8
  else
    Result := etUSASCII;
end;

end.
