unit WD.GR32Tools;

interface

uses
  System.SysUtils,
  System.Math,

  GR32,

  AnyiQuack;

function EaseColor32(StartColor, EndColor: TColor32; Progress: Real;
  const EaseFunction: TEaseFunction = nil): TColor32;

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

end.
