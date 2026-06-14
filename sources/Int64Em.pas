unit Int64Em;

{
  Inno Setup
  Copyright (C) 1997-2025 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  Declaration of the Integer64 type - which represents an *unsigned* 64-bit
  integer value - and functions for manipulating Integer64's.

  macOS/FPC port: the original x86 assembly implementations were replaced
  by portable pure-Pascal code using native 64-bit unsigned arithmetic.
}

interface

type
  Integer64 = record
    Lo, Hi: LongWord;
    class operator Implicit(const A: Integer64): Int64;
    class operator Implicit(const A: Int64): Integer64;
  end;

function Compare64(const N1, N2: Integer64): Integer;
procedure Dec64(var X: Integer64; N: LongWord);
procedure Dec6464(var X: Integer64; const N: Integer64);
function Div64(var X: Integer64; const Divisor: LongWord): LongWord;
function Inc64(var X: Integer64; N: LongWord): Boolean;
function Inc6464(var X: Integer64; const N: Integer64): Boolean;
function Mod64(const X: Integer64; const Divisor: LongWord): LongWord;
procedure Multiply32x32to64(N1, N2: LongWord; var X: Integer64);
function StrToInteger64(const S: String; var X: Integer64): Boolean; overload;
function StrToInteger64(const S: String; var X: Int64): Boolean; overload;

implementation

uses
  SysUtils;

function ToQWord(const X: Integer64): QWord; inline;
begin
  Result := (QWord(X.Hi) shl 32) or X.Lo;
end;

procedure FromQWord(const V: QWord; var X: Integer64); inline;
begin
  X.Lo := LongWord(V and $FFFFFFFF);
  X.Hi := LongWord(V shr 32);
end;

function Compare64(const N1, N2: Integer64): Integer;
{ If N1 = N2, returns 0.
  If N1 > N2, returns 1.
  If N1 < N2, returns -1. }
var
  A, B: QWord;
begin
  A := ToQWord(N1);
  B := ToQWord(N2);
  if A > B then
    Result := 1
  else if A < B then
    Result := -1
  else
    Result := 0;
end;

procedure Dec64(var X: Integer64; N: LongWord);
begin
  FromQWord(ToQWord(X) - N, X);
end;

procedure Dec6464(var X: Integer64; const N: Integer64);
begin
  FromQWord(ToQWord(X) - ToQWord(N), X);
end;

function Inc64(var X: Integer64; N: LongWord): Boolean;
{ Adds N to X. In case of overflow, False is returned. }
var
  V: QWord;
begin
  V := ToQWord(X);
  Result := N <= High(QWord) - V;
  FromQWord(V + N, X);
end;

function Inc6464(var X: Integer64; const N: Integer64): Boolean;
{ Adds N to X. In case of overflow, False is returned. }
var
  V, W: QWord;
begin
  V := ToQWord(X);
  W := ToQWord(N);
  Result := W <= High(QWord) - V;
  FromQWord(V + W, X);
end;

procedure Multiply32x32to64(N1, N2: LongWord; var X: Integer64);
{ Multiplies two 32-bit unsigned integers together and places the result
  in X. }
begin
  FromQWord(QWord(N1) * N2, X);
end;

function Mul64(var X: Integer64; N: LongWord): Boolean;
{ Multiplies X by N, and overwrites X with the result. In case of overflow,
  False is returned (X is valid but truncated to 64 bits). }
var
  V: QWord;
begin
  V := ToQWord(X);
  Result := (N = 0) or (V <= High(QWord) div N);
  FromQWord(V * N, X);
end;

function Div64(var X: Integer64; const Divisor: LongWord): LongWord;
{ Divides X by Divisor, and overwrites X with the quotient. Returns the
  remainder. }
var
  V: QWord;
begin
  V := ToQWord(X);
  Result := LongWord(V mod Divisor);
  FromQWord(V div Divisor, X);
end;

function Mod64(const X: Integer64; const Divisor: LongWord): LongWord;
{ Divides X by Divisor and returns the remainder. Unlike Div64, X is left
  intact. }
begin
  Result := LongWord(ToQWord(X) mod Divisor);
end;

function StrToInteger64(const S: String; var X: Integer64): Boolean;
{ Converts a string containing an unsigned decimal number, or hexadecimal
  number prefixed with '$', into an Integer64. Returns True if successful,
  or False if invalid characters were encountered or an overflow occurred.
  Supports digits separators. }
var
  Len, Base, StartIndex, I: Integer;
  V: Integer64;
  C: Char;
begin
  Result := False;

  Len := Length(S);
  Base := 10;
  StartIndex := 1;
  if Len > 0 then begin
    if S[1] = '$' then begin
      Base := 16;
      Inc(StartIndex);
    end else if S[1] = '_' then
      Exit;
  end;

  if (StartIndex > Len) or (S[StartIndex] = '_') then
    Exit;
  V := 0;
  for I := StartIndex to Len do begin
    C := UpCase(S[I]);
    case C of
      '0'..'9':
        begin
          if not Mul64(V, Base) then
            Exit;
          if not Inc64(V, Ord(C) - Ord('0')) then
            Exit;
        end;
      'A'..'F':
        begin
          if Base <> 16 then
            Exit;
          if not Mul64(V, Base) then
            Exit;
          if not Inc64(V, Ord(C) - (Ord('A') - 10)) then
            Exit;
        end;
      '_':
        { Ignore }
    else
      Exit;
    end;
  end;
  X := V;
  Result := True;
end;

function StrToInteger64(const S: String; var X: Int64): Boolean;
var
  X2: Integer64;
begin
  X2 := X;
  Result := StrToInteger64(S, X2);
  X := X2;
end;

{ Integer64 }

class operator Integer64.Implicit(const A: Int64): Integer64;
begin
  Int64Rec(Result) := Int64Rec(A);
end;

class operator Integer64.Implicit(const A: Integer64): Int64;
begin
  Int64Rec(Result) := Int64Rec(A);
end;

end.
