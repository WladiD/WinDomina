unit WD.Layer.Grid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Controls,

  GR32,
  GR32_Polygons,
  GR32_VectorUtils,
  AnyiQuack,
  AQPSystemTypesAnimations,
  WindowEnumerator,

  WD.Types,
  WD.Layer,
  WD.WindowTools,
  WD.KeyTools,
  WD.Registry;

type
  TTile = class
  public
    // Das vorherige Rechteck, welches als Basis f�r die Berechnung der Animation verwendet wird
    PrevRect: TRect;

    // Das aktuell dargestellte Rechteck, weicht vom TargetRect z.B. w�hrend der Animation ab
    Rect: TRect;

    // Das Ziel-Rechteck, welches effektiv benutzt werden soll
    TargetRect: TRect;
  end;

  TTileGrid = array [0..2] of array [0..2] of TTile;
  TQuotientGridArray = array [0..2] of TPointF;
  TQuotientGridStyle = (
    // Alle Kacheln in etwa gleich gro�
    qgsUniform,
    // 1. Spalte 50%, 2. Spalte 33%, 3. Spalte Restbreite
    qgsHalfThirdRemain,
    // 1. Spalte 40%, 2. und 3. jeweils die H�lfte von der Restbreite
    qgsFortyRemainUniform);

  TGridLayer = class(TBaseLayer)
  private
    class var
    TileSlideAniID: Integer;
  private
    FTileGrid: TTileGrid;
    QuotientGrid: TQuotientGridArray;
    QuotientGridStyle: TQuotientGridStyle;
    FirstTileNumKey: Integer;
    SecondTileNumKey: Integer;
    FSmallestNumSquare: Integer;

    procedure CalcCurrentTileGrid(var TileGrid: TTileGrid);
    procedure UpdateTileGrid;

    function IsXYToTileNumConvertible(X, Y: Integer; out TileNum: Integer): Boolean;
    function IsTileNumToXYConvertible(TileNum: Integer; out X, Y: Integer): Boolean;
    function IsTileNumKey(Key: Integer; out TileNum: Integer): Boolean;

  public
    class constructor Create;

    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;

    function HasMainContent: Boolean; override;
    procedure RenderMainContent(Target: TBitmap32); override;
    procedure Invalidate; override;
    function GetTargetWindowMovedDelay: Integer; override;

    property TileGrid: TTileGrid read FTileGrid;
  end;

  function GetQuotientGridArray(Style: TQuotientGridStyle): TQuotientGridArray;

implementation

function GetQuotientGridArray(Style: TQuotientGridStyle): TQuotientGridArray;
begin
  case Style of
    qgsUniform:
    begin
      Result[0].X := 1/3;
      Result[1].X := 1/3;
      Result[2].X := 0; // 0 steht f�r den gleichm��ig verteilten Rest

      Result[0].Y := 1/3;
      Result[1].Y := 1/3;
      Result[2].Y := 0;
    end;
    qgsHalfThirdRemain:
    begin
      Result[0].X := 1/2;
      Result[1].X := 0;
      Result[2].X := 0; // 0 steht f�r den gleichm��ig verteilten Rest

      Result[0].Y := 1/3;
      Result[1].Y := 1/3;
      Result[2].Y := 0;
    end;
    qgsFortyRemainUniform:
    begin
      Result[0].X := 1/2.5;
      Result[1].X := 0;
      Result[2].X := 0; // 0 steht f�r den gleichm��ig verteilten Rest

      Result[0].Y := 1/2;
      Result[1].Y := 1/4;
      Result[2].Y := 0;
    end;
  end;
end;

procedure InitializeTileGrid(var TileGrid: TTileGrid);
var
  TileX, TileY: Integer;
begin
  for TileX := 0 to High(TileGrid) do
    for TileY := 0 to High(TileGrid[TileX]) do
      TileGrid[TileX][TileY] := TTile.Create;
end;

procedure FinalizeTileGrid(var TileGrid: TTileGrid);
var
  TileX, TileY: Integer;
begin
  for TileX := 0 to High(TileGrid) do
    for TileY := 0 to High(TileGrid[TileX]) do
      FreeAndNil(TileGrid[TileX][TileY]);
end;

{ TGridLayer }

class constructor TGridLayer.Create;
begin
  TileSlideAniID := TAQ.GetUniqueID;
end;

constructor TGridLayer.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  InitializeTileGrid(FTileGrid);

  QuotientGrid := GetQuotientGridArray(qgsUniform);

  RegisterLayerActivationKeys([vkG]);
  FExclusive := True;
end;

destructor TGridLayer.Destroy;
begin
  FinalizeTileGrid(FTileGrid);

  inherited Destroy;
end;

procedure TGridLayer.EnterLayer;
var
  TileX, TileY: Integer;
  WAWidth, WAHeight: Integer;
  WorkareaRect: TRect;

  procedure InitPos(Tile: TTile);
  var
    Rect: PRect;
  begin
    Rect := @Tile.Rect;
    Rect.Left := -WAWidth;
    Rect.Top := WAHeight;
    Rect.Right := 0;
    Rect.Bottom := 0;
  end;

begin
  inherited EnterLayer;

  Randomize;

  WorkareaRect := MonitorHandler.CurrentMonitor.WorkareaRect;
  WAWidth := WorkareaRect.Width;
  WAHeight := WorkareaRect.Height;

  for TileX := 0 to High(TileGrid) do
    for TileY := 0 to High(TileGrid[TileX]) do
      InitPos(TileGrid[TileX][TileY]);

  UpdateTileGrid;

  AddLog('TGridLayer.EnterLayer');
end;

procedure TGridLayer.ExitLayer;
begin
  AddLog('TGridLayer.ExitLayer');
  inherited ExitLayer;
end;

function TGridLayer.GetTargetWindowMovedDelay: Integer;
begin
  // Da das Grid auf einem anderen Monitor als das Zielfenster sein k�nnte, kommt es ohne
  // diese Verz�gerung zu einem Sprungwechsel des Monitors w�hrend das Fenster bewegt wird.
  Result := 400;
end;

procedure TGridLayer.CalcCurrentTileGrid(var TileGrid: TTileGrid);
var
  XRemainCount, YRemainCount: Integer;
  cc, Xcc, Ycc: Integer;
  X, Y, XSize: Integer;
  WAWidth, WAHeight, RemainWidth, RemainHeight: Integer;
  WorkareaRect: TRect;
  XQuotient, YQuotient: Single;
  CurRect: System.Types.PRect;
begin
  WorkareaRect := MonitorHandler.CurrentMonitor.WorkareaRect;
  WAWidth := WorkareaRect.Width;
  WAHeight := WorkareaRect.Height;
  FSmallestNumSquare := Min(Max(50, Round(WAWidth * 0.05)), Max(50, Round(WAHeight * 0.05)));

  RemainWidth := WAWidth;
  RemainHeight := WAHeight;

  // Anzahl von 0-Definition, diese werden f�r die gleichm��ige Verteilung des Restes verwendet
  XRemainCount := 0;
  YRemainCount := 0;

  for cc := 0 to 2 do
  begin
    XQuotient := QuotientGrid[cc].X;
    YQuotient := QuotientGrid[cc].Y;

    if XQuotient > 0 then
      RemainWidth := RemainWidth - Trunc(WAWidth * XQuotient)
    else if XQuotient = 0 then
      Inc(XRemainCount);

    if YQuotient > 0 then
      RemainHeight := RemainHeight - Trunc(WAHeight * YQuotient)
    else if YQuotient = 0 then
      Inc(YRemainCount);
  end;

  X := 0;

  for Xcc := 0 to 2 do
  begin
    XQuotient := QuotientGrid[Xcc].X;
    if XQuotient = 0 then
      XSize := Trunc(RemainWidth / XRemainCount)
    else
      XSize := Trunc(WAWidth * XQuotient);

    Y := 0;

    for Ycc := 0 to 2 do
    begin
      CurRect := @(TileGrid[Xcc][Ycc].Rect);
      CurRect.Left := X;
      CurRect.Top := Y;

      YQuotient := QuotientGrid[Ycc].Y;
      if YQuotient = 0 then
        Inc(Y, Trunc(RemainHeight / YRemainCount))
      else
        Inc(Y, Trunc(WAHeight * YQuotient));

      CurRect.Right := X + XSize;
      CurRect.Bottom := Y;
      TileGrid[Xcc][Ycc].TargetRect := CurRect^;
    end;
    Inc(X, XSize);
  end;
end;

procedure TGridLayer.UpdateTileGrid;

  procedure AnimateTile(Tile: TTile);
  var
    TargetRect: TRect;
  begin
    TargetRect := Tile.Rect;
    Tile.Rect := Tile.PrevRect;
    Take(Tile)
      .CancelAnimations(TileSlideAniID)
      .Plugin<TAQPSystemTypesAnimations>
      .RectAnimation(TargetRect,
        function(RefObject: TObject): TRect
        begin
          Result := TTile(RefObject).Rect;
        end,
        procedure(RefObject: TObject; const NewRect: TRect)
        begin
          TTile(RefObject).Rect := NewRect;
          InvalidateMainContent;
        end,
        250, TileSlideAniID, TAQ.Ease(TEaseType.etSinus));
  end;

  procedure SaveTileRect(Tile: TTile);
  begin
    Tile.PrevRect := Tile.Rect;
  end;

var
  TileX, TileY: Integer;
begin
  for TileX := 0 to High(TileGrid) do
    for TileY := 0 to High(TileGrid[TileX]) do
      SaveTileRect(TileGrid[TileX][TileY]);

  CalcCurrentTileGrid(FTileGrid);

  for TileX := 0 to High(TileGrid) do
    for TileY := 0 to High(TileGrid[TileX]) do
      AnimateTile(TileGrid[TileX][TileY]);
end;

const
  TileCoord: array[1..9] of TPoint = (
    {1} (X: 0; Y: 2),
    {2} (X: 1; Y: 2),
    {3} (X: 2; Y: 2),
    {4} (X: 0; Y: 1),
    {5} (X: 1; Y: 1),
    {6} (X: 2; Y: 1),
    {7} (X: 0; Y: 0),
    {8} (X: 1; Y: 0),
    {9} (X: 2; Y: 0));

function TGridLayer.IsXYToTileNumConvertible(X, Y: Integer; out TileNum: Integer): Boolean;
var
  Point: PPoint;
  cc: Integer;
begin
  Result := True;
  for cc := 1 to 9 do
  begin
    Point := @TileCoord[cc];
    if (Point.X = X) and (Point.Y = Y) then
      Exit;
  end;
  Result := False;
end;

function TGridLayer.IsTileNumToXYConvertible(TileNum: Integer; out X, Y: Integer): Boolean;
var
  Point: PPoint;
begin
  Result := (TileNum >= 1) and (TileNum <= 9);
  if Result then
  begin
    Point := @TileCoord[TileNum];
    X := Point.X;
    Y := Point.Y;
  end;
end;

function TGridLayer.IsTileNumKey(Key: Integer; out TileNum: Integer): Boolean;
begin
  Result := True;

  if Key in [vkNumpad1..vkNumpad9] then
    TileNum := (Key - vkNumpad1) + 1
  else if Key in [vk1..vk9] then
    TileNum := (Key - vk1) + 1
  else
    Result := False;
end;

procedure TGridLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);
var
  TileNum: Integer;
  Monitor: TMonitor;
begin
  if IsTileNumKey(Key, TileNum) then
  begin
    if FirstTileNumKey = 0 then
      FirstTileNumKey := Key
    else
      SecondTileNumKey := Key;

    Handled := True;
  end;

  case Key of
    vkG:
    begin
      if QuotientGridStyle < High(QuotientGridStyle) then
        QuotientGridStyle := Succ(QuotientGridStyle)
      else
        QuotientGridStyle := Low(QuotientGridStyle);

      QuotientGrid := GetQuotientGridArray(QuotientGridStyle);
      UpdateTileGrid;
      Handled := True;
    end;
    vkTab:
    begin
      if MonitorHandler.HasNextMonitor(Monitor) then
        MonitorHandler.SetCurrentMonitor(Monitor);
      Handled := True;
    end;
  end;
end;

procedure TGridLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
var
  TileNum: Integer;
  TargetWindow: TWindow;

  procedure SizeWindowRect(const Rect: TRect);
  begin
    WindowPositioner.EnterWindow(TargetWindow.Handle);
    try
      WindowPositioner.PlaceWindow(Rect);
    finally
      WindowPositioner.ExitWindow;
    end;
  end;

  procedure HandleTileNumKey;
  var
    HasFirstTileNumKey, HasSecondTileNumKey: Boolean;
    FirstTileNum, SecondTileNum: Integer;
    FirstRect, SecondRect: TRect;
    TileX, TileY: Integer;
  begin
    HasFirstTileNumKey := FirstTileNumKey <> 0;
    HasSecondTileNumKey := SecondTileNumKey <> 0;

    if (HasFirstTileNumKey and WDMKeyStates.KeyPressed[FirstTileNumKey]) or
      (HasSecondTileNumKey and WDMKeyStates.KeyPressed[SecondTileNumKey]) then
      Exit;

    FirstTileNum := 0;
    SecondTileNum := 0;

    if HasFirstTileNumKey and IsTileNumKey(FirstTileNumKey, FirstTileNum) and
      IsTileNumToXYConvertible(FirstTileNum, TileX, TileY) then
      FirstRect := MonitorHandler.ClientToScreen(TileGrid[TileX][TileY].TargetRect);

    if HasSecondTileNumKey and IsTileNumKey(SecondTileNumKey, SecondTileNum) and
      IsTileNumToXYConvertible(SecondTileNum, TileX, TileY) then
      SecondRect := MonitorHandler.ClientToScreen(TileGrid[TileX][TileY].TargetRect);

    if (FirstTileNum > 0) and (SecondTileNum > 0) then
      SizeWindowRect(TRect.Union(FirstRect, SecondRect))
    else if FirstTileNum > 0 then
      SizeWindowRect(FirstRect);

    FirstTileNumKey := 0;
    SecondTileNumKey := 0;
  end;

begin
  if not HasTargetWindow(TargetWindow) then
    Exit;

  if IsTileNumKey(Key, TileNum) then
  begin
    HandleTileNumKey;
    Handled := True;
  end;
end;

function TGridLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

procedure TGridLayer.RenderMainContent(Target: TBitmap32);
var
  TileNum, TileX, TileY: Integer;

  procedure DrawTile(Tile: TTile);
  var
    cc: Integer;
    Rect: TRect;
    NumX, NumY: Integer;
  begin
    Rect := Tile.Rect;
    for cc := 1 to 3 do
    begin
      Target.FrameRectS(Rect, clBlack32);
      Rect.Inflate(-1, -1);
    end;

    for cc := 1 to 3 do
    begin
      Target.FrameRectS(Rect, clWhite32);
      Rect.Inflate(-1, -1);
    end;

    NumX := Rect.Left + ((Rect.Width - FSmallestNumSquare) div 2);
    NumY := Rect.Top + ((Rect.Height - FSmallestNumSquare) div 2);

    KeyRenderManager.Render(Target, TileNum + vk0,
      System.Types.Rect(NumX, NumY, NumX + FSmallestNumSquare, NumY + FSmallestNumSquare), ksFlat);

    // Diese Variante ist um den Faktor 5-7 langsamer
//    Target.FillRectS(Rect, clBlack32);
//    Rect.Inflate(-3, -3);
//    Target.FillRectS(Rect, clWhite32);
//    Rect.Inflate(-3, -3);
//    Target.FillRectS(Rect, SetAlpha(clBlack32, 0));

    // Diese Variante ist noch langsamer, ca. 50 mal langsamer
//    PolylineFS(Target, Rectangle(FloatRect(Rect)), clBlack32, True, 3);
//    Rect.Inflate(-4, -4);
//    PolylineFS(Target, Rectangle(FloatRect(Rect)), clWhite32, True, 3);
  end;

begin
  inherited RenderMainContent(Target);

  for TileNum := 1 to 9 do
    if IsTileNumToXYConvertible(TileNum, TileX, TileY) then
      DrawTile(TileGrid[TileX][TileY]);
end;

procedure TGridLayer.Invalidate;
begin
  UpdateTileGrid;
end;

end.
