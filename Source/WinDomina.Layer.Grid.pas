unit WinDomina.Layer.Grid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  Winapi.Windows,
  Winapi.D2D1,
  Vcl.Graphics,
  Vcl.Direct2D,
  WinDomina.Types,
  WinDomina.Layer,
  WinDomina.WindowTools,
  WinDomina.Registry,
  WinDomina.Types.Drawing;

type
  TRect3x3GridArray = array [0..2] of array [0..2] of TRect;
  TQuotientGridArray = array [0..2] of TPointF;

  TGridLayer = class(TBaseLayer)
  private
    FRectGrid: TRect3x3GridArray;
    QuotientGrid: TQuotientGridArray;

    function CalcCurrentRectGrid: TRect3x3GridArray;
    procedure UpdateRectGrid;

    function XYToTileNum(X, Y: Integer): Integer;
    procedure TileNumToXY(TileNum: Integer; out X, Y: Integer);

  public
    constructor Create; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;

    function HasMainContent(const DrawContext: IDrawContext;
      var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean; override;
    procedure RenderMainContent(const DrawContext: IDrawContext;
      const LayerParams: TD2D1LayerParameters); override;
    procedure InvalidateMainContentResources; override;

    property RectGrid: TRect3x3GridArray read FRectGrid;
  end;

implementation

{ TGridLayer }

constructor TGridLayer.Create;
begin
  inherited Create;

  QuotientGrid[0].X := 1/3;
  QuotientGrid[1].X := 1/3;
  QuotientGrid[2].X := 0; // 0 steht für den gleichmäßig verteilten Rest

  QuotientGrid[0].Y := 1/3;
  QuotientGrid[1].Y := 1/3;
  QuotientGrid[2].Y := 0;

//  QuotientGrid[0].X := 1/2;
//  QuotientGrid[1].X := 1/3;
//  QuotientGrid[2].X := 0; // 0 steht für den gleichmäßig verteilten Rest
//
//  QuotientGrid[0].Y := 1/3;
//  QuotientGrid[1].Y := 1/3;
//  QuotientGrid[2].Y := 0;

  RegisterLayerActivationKeys([vkNumpad0, vkNumpad1, vkNumpad2, vkNumpad3, vkNumpad4, vkNumpad5,
    vkNumpad6, vkNumpad7, vkNumpad8, vkNumpad9]);
end;

procedure TGridLayer.EnterLayer;
begin
  inherited EnterLayer;

  UpdateRectGrid;

  AddLog('TGridLayer.EnterLayer');
end;

procedure TGridLayer.ExitLayer;
begin
  AddLog('TGridLayer.ExitLayer');
  inherited ExitLayer;
end;

function TGridLayer.CalcCurrentRectGrid: TRect3x3GridArray;
var
  XRemainCount, YRemainCount: Integer;
  cc, Xcc, Ycc: Integer;
  X, Y, XSize: Integer;
  WAWidth, WAHeight, RemainWidth, RemainHeight: Integer;
  LocalDominaWindows: TWindowList;
  WorkareaRect: TRect;
  XQuotient, YQuotient: Single;
  CurRect: System.Types.PRect;
begin
  LocalDominaWindows := DominaWindows;
  WorkareaRect := GetWorkareaRect(LocalDominaWindows[0]);
  WAWidth := WorkareaRect.Width;
  WAHeight := WorkareaRect.Height;
  RemainWidth := WAWidth;
  RemainHeight := WAHeight;

  // Anzahl von 0-Definition, diese
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
    YQuotient := QuotientGrid[Xcc].Y;
    Y := 0;

    if XQuotient = 0 then
      XSize := Trunc(RemainWidth / XRemainCount)
    else
      XSize := Trunc(WAWidth * XQuotient);

    for Ycc := 0 to 2 do
    begin
      CurRect := @Result[Xcc][Ycc];
      CurRect.Left := X;
      CurRect.Top := Y;

      if YQuotient = 0 then
        Inc(Y, Trunc(RemainHeight / YRemainCount))
      else
        Inc(Y, Trunc(WAHeight * YQuotient));

      CurRect.Right := X + XSize;
      CurRect.Bottom := Y;
    end;
    Inc(X, XSize);
  end;
end;

procedure TGridLayer.UpdateRectGrid;
begin
  FRectGrid := CalcCurrentRectGrid;
end;

function TGridLayer.XYToTileNum(X, Y: Integer): Integer;
begin

end;

procedure TGridLayer.TileNumToXY(TileNum: Integer; out X, Y: Integer);
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
var
  Point: PPoint;
begin
  if (TileNum >= 1) and (TileNum <= 9) then
  begin
    Point := @TileCoord[TileNum];
    X := Point.X;
    Y := Point.Y;
  end
  else
  begin
    X := -1;
    Y := -1;
  end;
end;

procedure TGridLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  procedure SizeWindowTile(TileX, TileY: Integer);
  var
    Window: THandle;
    Rect: TRect;
    LocalDominaWindows: TWindowList;
  begin
    LocalDominaWindows := DominaWindows;
    if LocalDominaWindows.Count = 0 then
      Exit;

    Window := LocalDominaWindows[0];
    Rect := RectGrid[TileX][TileY];

    SetWindowPosDominaStyle(Window, 0, Rect, SWP_NOZORDER);
  end;

var
  TileX, TileY: Integer;
begin
  case Key of
    vkNumpad1..vkNumpad9:
    begin
      TileNumToXY((Key - vkNumpad1) + 1, TileX, TileY);
      if (TileX >= 0) or (TileY >= 0) then
      begin
        SizeWindowTile(TileX, TileY);
        Handled := True;
      end;
    end;
  end;
end;

procedure TGridLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

function TGridLayer.HasMainContent(const DrawContext: IDrawContext;
  var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean;
begin
  Result := IsLayerActive;
  if not Result then
    Exit;
end;

procedure TGridLayer.RenderMainContent(const DrawContext: IDrawContext;
  const LayerParams: TD2D1LayerParameters);
var
  EllipseBrush: ID2D1SolidColorBrush;
  RT: ID2D1RenderTarget;
begin
  RT := DrawContext.RenderTarget;

  RT.CreateSolidColorBrush(D2D1ColorF(clBlack, 0.5), nil, EllipseBrush);
  RT.FillEllipse(D2D1Ellipse(D2D1PointF(0, 0), 100, 100), EllipseBrush);
end;

procedure TGridLayer.InvalidateMainContentResources;
begin

end;

end.
