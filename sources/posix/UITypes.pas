unit UITypes;

{
  Minimal replacement for the Delphi System.UITypes unit (macOS/FPC port of
  innounp): only TColor/TColors as used by Main.pas. Values follow the VCL
  BGR convention.
}

interface

{$MODE DELPHIUNICODE}

type
  TColor = -$7FFFFFFF-1..$7FFFFFFF;

  TColors = record
  const
    White  = TColor($FFFFFF);
    Red    = TColor($0000FF);
    Green  = TColor($008000);
    Blue   = TColor($FF0000);
    Maroon = TColor($000080);
    Purple = TColor($800080);
    Aqua   = TColor($FFFF00);
  end;

implementation

end.
