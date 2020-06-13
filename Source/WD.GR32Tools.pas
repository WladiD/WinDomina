unit WD.GR32Tools;

interface

uses
  System.SysUtils,
  System.Math,
  System.Types,
  Vcl.Graphics,

  GR32,
  GR32_Blend,

  AnyiQuack;

function EaseColor32(StartColor, EndColor: TColor32; Progress: Real;
  const EaseFunction: TEaseFunction = nil): TColor32;

procedure MergedDraw(Source, Target: TBitmap32; TargetX, TargetY: Integer);
procedure MergedDrawUnsafe(Source, Target: TBitmap32; TargetX, TargetY: Integer);

type
  TBitmap32Helper = class helper for TBitmap32
  public
    procedure RenderTextWD(X, Y: Integer; const Text: string; Color: TColor32);
  end;

implementation

function EaseColor32(StartColor, EndColor: TColor32; Progress: Real;
  const EaseFunction: TEaseFunction): TColor32;
var
  StartCR, EndCR: TColor32Entry;
begin
  if StartColor = EndColor then
    Exit(StartColor)
  else if Progress = 1 then
    Exit(EndColor);

  StartCR.ARGB := StartColor;
  EndCR.ARGB := EndColor;
  if Assigned(EaseFunction) then
    Progress := EaseFunction(Progress);

  Result := Color32(
    Min(255, Max(0, TAQ.EaseInteger(StartCR.R, EndCR.R, Progress, nil))),
    Min(255, Max(0, TAQ.EaseInteger(StartCR.G, EndCR.G, Progress, nil))),
    Min(255, Max(0, TAQ.EaseInteger(StartCR.B, EndCR.B, Progress, nil))),
    Min(255, Max(0, TAQ.EaseInteger(StartCR.A, EndCR.A, Progress, nil))));
end;

procedure MergedDraw(Source, Target: TBitmap32; TargetX, TargetY: Integer);
var
  SourceX, SourceY, CumTargetX, CumTargetY: Integer;
  PSrc, PDst: PColor32Array;
begin
  if (TargetX < 0) or (TargetY < 0) then
    Exit;

  for SourceY := 0 to Source.Height - 1 do
  begin
    CumTargetY := TargetY + SourceY;

    if CumTargetY >= Target.Height then
      Exit;

    PSrc := PColor32Array(Source.ScanLine[SourceY]);
    PDst := PColor32Array(Target.ScanLine[CumTargetY]);
    for SourceX := 0 to Source.Width - 1 do
    begin
      CumTargetX := SourceX + TargetX;
      if CumTargetX >= Target.Width then
        Break;
      MergeMem(PSrc[SourceX], PDst[CumTargetX]);
    end;
  end
end;

procedure MergedDrawUnsafe(Source, Target: TBitmap32; TargetX, TargetY: Integer);
var
  SourceX, SourceY: Integer;
  PSrc, PDst: PColor32Array;
begin
  if (TargetX < 0) or (TargetY < 0) then
    Exit;

  for SourceY := 0 to Source.Height - 1 do
  begin
    PSrc := PColor32Array(Source.ScanLine[SourceY]);
    PDst := PColor32Array(Target.ScanLine[TargetY + SourceY]);
    for SourceX := 0 to Source.Width - 1 do
      MergeMem(PSrc[SourceX], PDst[SourceX + TargetX]);
  end
end;

{ TBitmap32Helper }

// Copied from GR32.pas and optimized
procedure TextBlueToAlpha(B: TCustomBitmap32; Color: TColor32);
const
  WhiteLocal: TColor32 = clWhite;
var
  BlueMasterAlpha: Byte;
  I: Integer;
  P: PColor32;
  OpaqueColor: TColor32;
begin
  BlueMasterAlpha := Color shr 24;

  // If the passed color is opaque, so we decrease the master alpha for better results
  if BlueMasterAlpha = $FF then
    BlueMasterAlpha := 200;

  OpaqueColor := Color and $00FFFFFF; // Remove alpha channel from the passed color

  P := @B.Bits[0];
  for I := 0 to B.Width * B.Height - 1 do
  begin
    if P^ = WhiteLocal then
      P^ := Color
    // Transfer the blue channel to alpha and add the color
    else
      P^ := (DivTable[P^ and $000000FF, BlueMasterAlpha] shl 24) + OpaqueColor;  // DivTableBit-Version (fast version)
//      P^ := ((((P^ and $000000FF) * BlueMasterAlpha) div 255) shl 24) + OpaqueColor; // AlwaysCalc-Version (slow version because always calculated)
    Inc(P);
  end;
end;

// Copied TBitmap32.RenderText from GR32.pas and adjusted for WinDomina needs
procedure TBitmap32Helper.RenderTextWD(X, Y: Integer; const Text: string; Color: TColor32);
var
  B: TBitmap32;
  Size: TSize;
begin
  if Empty then
    Exit;

  B := TBitmap32.Create;
  try
    Size := TextExtent(Text + ' ');
    if Size.cX > Width then
      Size.cX := Width;
    if Size.cY > Height then
      Size.cX := Height;
    B.SetSize(Size.cX, Size.cY);
    B.Font := Font;
    B.Clear(0);
    B.Font.Color := clWhite;
    B.Textout(0, 0, Text);
    TextBlueToAlpha(B, Color);
    MergedDraw(B, Self, X, Y);
  finally
    B.Free;
  end;
end;

end.
