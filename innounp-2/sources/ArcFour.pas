unit ArcFour;

{
  Inno Setup
  Copyright (C) 1997-2004 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  ARCFOUR (RC4) encryption/decryption.

  macOS/FPC port: the original implementation linked the x86 ISCrypt.obj.
  This is a portable pure-Pascal replacement of the standard RC4 algorithm,
  bit-for-bit compatible with ISCrypt's ArcFourInit/ArcFourCrypt.
}

interface

uses
  SysUtils;

type
  TArcFourContext = record
    state: array[0..255] of Byte;
    x, y: Byte;
  end;

function ArcFourInitFunctions(Module: PtrUInt): Boolean;
procedure ArcFourInit(var Context: TArcFourContext; const Key;
  KeyLength: Cardinal);
procedure ArcFourCrypt(var Context: TArcFourContext; const InBuffer;
  var OutBuffer; Length: Cardinal);
procedure ArcFourDiscard(var Context: TArcFourContext; Bytes: Cardinal);

implementation

function ArcFourInitFunctions(Module: PtrUInt): Boolean;
begin
  { No external library to bind to anymore }
  Result := True;
end;

procedure ArcFourInit(var Context: TArcFourContext; const Key;
  KeyLength: Cardinal);
var
  i: Integer;
  j: Byte;
  t: Byte;
  K: PByteArray;
begin
  K := @Key;
  for i := 0 to 255 do
    Context.state[i] := Byte(i);
  Context.x := 0;
  Context.y := 0;
  j := 0;
  for i := 0 to 255 do begin
    j := Byte(j + Context.state[i] + K^[i mod KeyLength]);
    t := Context.state[i];
    Context.state[i] := Context.state[j];
    Context.state[j] := t;
  end;
end;

procedure ArcFourCrypt(var Context: TArcFourContext; const InBuffer;
  var OutBuffer; Length: Cardinal);
var
  i: Cardinal;
  x, y, t: Byte;
  InP, OutP: PByteArray;
begin
  { InBuffer/OutBuffer may be nil (see ArcFourDiscard), in which case only
    the cipher state is advanced. }
  InP := @InBuffer;
  OutP := @OutBuffer;
  x := Context.x;
  y := Context.y;
  for i := 0 to Length - 1 do begin
    x := Byte(x + 1);
    y := Byte(y + Context.state[x]);
    t := Context.state[x];
    Context.state[x] := Context.state[y];
    Context.state[y] := t;
    if (InP <> nil) and (OutP <> nil) then
      OutP^[i] := InP^[i] xor Context.state[Byte(Context.state[x] + Context.state[y])];
  end;
  Context.x := x;
  Context.y := y;
end;

procedure ArcFourDiscard(var Context: TArcFourContext; Bytes: Cardinal);
begin
  ArcFourCrypt(Context, Pointer(nil)^, Pointer(nil)^, Bytes);
end;

end.
