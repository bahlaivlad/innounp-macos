unit HashCompat;

{
  Minimal replacement for the Delphi System.Hash unit (macOS/FPC port of
  innounp). Provides THashSHA2 with just the members used by SHA256.pas and
  PBKDF2.pas, backed by a pure-Pascal SHA-256 implementation.
}

interface

{$MODE DELPHIUNICODE}

uses
  SysUtils;

type
  TSHA256State = record
    H: array[0..7] of Cardinal;
    Buffer: array[0..63] of Byte;
    BufLen: Cardinal;
    TotalLen: QWord;
  end;

  THashSHA2 = record
  public type
    TSHA2Version = (SHA224, SHA256, SHA384, SHA512, SHA512_224, SHA512_256);
  private
    FState: TSHA256State;
  public
    class function Create(AVersion: TSHA2Version = TSHA2Version.SHA256): THashSHA2; static;
    function GetHashSize: Integer;
    function GetBlockSize: Integer;
    procedure Update(const AData; ALength: Cardinal); overload;
    procedure Update(const AData: TBytes; ALength: Cardinal = 0); overload;
    function HashAsBytes: TBytes;
    class function GetHMACAsBytes(const AData, AKey: TBytes;
      AVersion: TSHA2Version = TSHA2Version.SHA256): TBytes; static;
  end;

procedure SHA256CoreInit(var S: TSHA256State);
procedure SHA256CoreUpdate(var S: TSHA256State; const Data; Len: Cardinal);
procedure SHA256CoreFinal(var S: TSHA256State; out Digest: array of Byte);

implementation

const
  K: array[0..63] of Cardinal = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

function Ror(X: Cardinal; N: Byte): Cardinal; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

procedure SHA256Compress(var S: TSHA256State; Block: PByte);
var
  W: array[0..63] of Cardinal;
  A, B, C, D, E, F, G, H, T1, T2: Cardinal;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (Cardinal(Block[I*4]) shl 24) or (Cardinal(Block[I*4+1]) shl 16) or
            (Cardinal(Block[I*4+2]) shl 8) or Cardinal(Block[I*4+3]);
  for I := 16 to 63 do
    W[I] := (Ror(W[I-2], 17) xor Ror(W[I-2], 19) xor (W[I-2] shr 10)) + W[I-7] +
            (Ror(W[I-15], 7) xor Ror(W[I-15], 18) xor (W[I-15] shr 3)) + W[I-16];

  A := S.H[0]; B := S.H[1]; C := S.H[2]; D := S.H[3];
  E := S.H[4]; F := S.H[5]; G := S.H[6]; H := S.H[7];

  for I := 0 to 63 do begin
    T1 := H + (Ror(E, 6) xor Ror(E, 11) xor Ror(E, 25)) + ((E and F) xor ((not E) and G)) + K[I] + W[I];
    T2 := (Ror(A, 2) xor Ror(A, 13) xor Ror(A, 22)) + ((A and B) xor (A and C) xor (B and C));
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;

  Inc(S.H[0], A); Inc(S.H[1], B); Inc(S.H[2], C); Inc(S.H[3], D);
  Inc(S.H[4], E); Inc(S.H[5], F); Inc(S.H[6], G); Inc(S.H[7], H);
end;

procedure SHA256CoreInit(var S: TSHA256State);
begin
  S.H[0] := $6a09e667; S.H[1] := $bb67ae85; S.H[2] := $3c6ef372; S.H[3] := $a54ff53a;
  S.H[4] := $510e527f; S.H[5] := $9b05688c; S.H[6] := $1f83d9ab; S.H[7] := $5be0cd19;
  S.BufLen := 0;
  S.TotalLen := 0;
end;

procedure SHA256CoreUpdate(var S: TSHA256State; const Data; Len: Cardinal);
var
  P: PByte;
  N: Cardinal;
begin
  P := @Data;
  Inc(S.TotalLen, Len);
  while Len > 0 do begin
    N := 64 - S.BufLen;
    if N > Len then N := Len;
    Move(P^, S.Buffer[S.BufLen], N);
    Inc(S.BufLen, N);
    Inc(P, N);
    Dec(Len, N);
    if S.BufLen = 64 then begin
      SHA256Compress(S, @S.Buffer[0]);
      S.BufLen := 0;
    end;
  end;
end;

procedure SHA256CoreFinal(var S: TSHA256State; out Digest: array of Byte);
var
  BitLen: QWord;
  Pad: array[0..71] of Byte;
  PadLen: Cardinal;
  I: Integer;
begin
  BitLen := S.TotalLen * 8;
  FillChar(Pad, SizeOf(Pad), 0);
  Pad[0] := $80;
  { Pad to 56 mod 64 }
  PadLen := (56 + 64 - (S.TotalLen mod 64)) mod 64;
  if PadLen = 0 then PadLen := 64;
  for I := 0 to 7 do
    Pad[PadLen + I] := Byte(BitLen shr (56 - I*8));
  SHA256CoreUpdate(S, Pad, PadLen + 8);
  for I := 0 to 7 do begin
    Digest[I*4]   := Byte(S.H[I] shr 24);
    Digest[I*4+1] := Byte(S.H[I] shr 16);
    Digest[I*4+2] := Byte(S.H[I] shr 8);
    Digest[I*4+3] := Byte(S.H[I]);
  end;
end;

{ THashSHA2 }

class function THashSHA2.Create(AVersion: TSHA2Version): THashSHA2;
begin
  if AVersion <> TSHA2Version.SHA256 then
    raise Exception.Create('HashCompat: only SHA256 is supported');
  SHA256CoreInit(Result.FState);
end;

function THashSHA2.GetHashSize: Integer;
begin
  Result := 32;
end;

function THashSHA2.GetBlockSize: Integer;
begin
  Result := 64;
end;

procedure THashSHA2.Update(const AData; ALength: Cardinal);
begin
  SHA256CoreUpdate(FState, AData, ALength);
end;

procedure THashSHA2.Update(const AData: TBytes; ALength: Cardinal);
begin
  if ALength = 0 then
    ALength := Length(AData);
  if ALength > 0 then
    SHA256CoreUpdate(FState, AData[0], ALength);
end;

function THashSHA2.HashAsBytes: TBytes;
var
  Digest: array[0..31] of Byte;
begin
  { Delphi's THashSHA2 leaves the hash usable; innounp never reuses it after
    finalizing, so finalize in place. }
  SHA256CoreFinal(FState, Digest);
  SetLength(Result, 32);
  Move(Digest[0], Result[0], 32);
end;

class function THashSHA2.GetHMACAsBytes(const AData, AKey: TBytes;
  AVersion: TSHA2Version): TBytes;
var
  KeyBlock: array[0..63] of Byte;
  Pad: array[0..63] of Byte;
  Inner: THashSHA2;
  InnerDigest: TBytes;
  K0: TBytes;
  I: Integer;
begin
  if AVersion <> TSHA2Version.SHA256 then
    raise Exception.Create('HashCompat: only SHA256 is supported');

  FillChar(KeyBlock, SizeOf(KeyBlock), 0);
  if Length(AKey) > 64 then begin
    Inner := THashSHA2.Create;
    Inner.Update(AKey);
    K0 := Inner.HashAsBytes;
    Move(K0[0], KeyBlock[0], Length(K0));
  end else if Length(AKey) > 0 then
    Move(AKey[0], KeyBlock[0], Length(AKey));

  for I := 0 to 63 do
    Pad[I] := KeyBlock[I] xor $36;
  Inner := THashSHA2.Create;
  Inner.Update(Pad, 64);
  Inner.Update(AData);
  InnerDigest := Inner.HashAsBytes;

  for I := 0 to 63 do
    Pad[I] := KeyBlock[I] xor $5C;
  Inner := THashSHA2.Create;
  Inner.Update(Pad, 64);
  Inner.Update(InnerDigest);
  Result := Inner.HashAsBytes;
end;

end.
