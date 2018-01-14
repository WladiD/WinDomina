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
    FirstTileNumKey: Integer;
    SecondTileNumKey: Integer;

    function CalcCurrentRectGrid: TRect3x3GridArray;
    procedure UpdateRectGrid;

    function IsXYToTileNumConvertible(X, Y: Integer; out TileNum: Integer): Boolean;
    function IsTileNumToXYConvertible(TileNum: Integer; out X, Y: Integer): Boolean;
    function IsTileNumKey(Key: Integer; out TileNum: Integer): Boolean;

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

// Alle Kacheln in etwa gleich groß
  QuotientGrid[0].X := 1/3;
  QuotientGrid[1].X := 1/3;
  QuotientGrid[2].X := 0; // 0 steht für den gleichmäßig verteilten Rest

  QuotientGrid[0].Y := 1/3;
  QuotientGrid[1].Y := 1/3;
  QuotientGrid[2].Y := 0;

// 1. Spalte 50%, 2. Spalte 33%, 3. Spalte Restbreite
//  QuotientGrid[0].X := 1/2;
//  QuotientGrid[1].X := 1/3;
//  QuotientGrid[2].X := 0; // 0 steht für den gleichmäßig verteilten Rest
//
//  QuotientGrid[0].Y := 1/3;
//  QuotientGrid[1].Y := 1/3;
//  QuotientGrid[2].Y := 0;

// 1. Spalte 40%, 2. und 3. jeweils die Hälfte von der Restbreite
//  QuotientGrid[0].X := 1/2.5;
//  QuotientGrid[1].X := 0;
//  QuotientGrid[2].X := 0; // 0 steht für den gleichmäßig verteilten Rest
//
//  QuotientGrid[0].Y := 1/2;
//  QuotientGrid[1].Y := 1/4;
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
    if XQuotient = 0 then
      XSize := Trunc(RemainWidth / XRemainCount)
    else
      XSize := Trunc(WAWidth * XQuotient);

    Y := 0;

    for Ycc := 0 to 2 do
    begin
      CurRect := @Result[Xcc][Ycc];
      CurRect.Left := X;
      CurRect.Top := Y;

      YQuotient := QuotientGrid[Ycc].Y;
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
  Result := Key in [vkNumpad1..vkNumpad9];
  if Result then
    TileNum := (Key - vkNumpad1) + 1;
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
  TileX, TileY, TileNum: Integer;
begin
  if IsTileNumKey(Key, TileNum) then
  begin
    if FirstTileNumKey = 0 then
      FirstTileNumKey := Key
    else
      SecondTileNumKey := Key;

    Handled := True;
//    if IsTileNumToXYConvertible(TileNum, TileX, TileY) then
//    begin
//      SizeWindowTile(TileX, TileY);
//
//    end;
  end;
end;

procedure TGridLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
var
  TileNum: Integer;

  procedure SizeWindowRect(const Rect: TRect);
  var
    Window: THandle;
    LocalDominaWindows: TWindowList;
  begin
    LocalDominaWindows := DominaWindows;
    if LocalDominaWindows.Count = 0 then
      Exit;

    Window := LocalDominaWindows[0];

    SetWindowPosDominaStyle(Window, 0, Rect, SWP_NOZORDER);
  end;

  procedure HandleTileNumKey;
  var
    HasFirstTileNumKey, HasSecondTileNumKey: Boolean;
    FirstTileNum, SecondTileNum: Integer;
    FirstRect, SecondRect, ActualRect: TRect;
    TileX, TileY: Integer;
  begin
    HasFirstTileNumKey := FirstTileNumKey <> 0;
    HasSecondTileNumKey := SecondTileNumKey <> 0;

    if (HasFirstTileNumKey and WDMKeyStates.KeyPressed[FirstTileNumKey]) or
      (HasSecondTileNumKey and WDMKeyStates.KeyPressed[SecondTileNumKey]) then
      Exit;

    if HasFirstTileNumKey and IsTileNumKey(FirstTileNumKey, FirstTileNum) and
      IsTileNumToXYConvertible(FirstTileNum, TileX, TileY) then
      FirstRect := RectGrid[TileX][TileY];

    if HasSecondTileNumKey and IsTileNumKey(SecondTileNumKey, SecondTileNum) and
      IsTileNumToXYConvertible(SecondTileNum, TileX, TileY) then
      SecondRect := RectGrid[TileX][TileY];

    if (FirstTileNum > 0) and (SecondTileNum > 0) then
      SizeWindowRect(TRect.Union(FirstRect, SecondRect))
    else if FirstTileNum > 0 then
      SizeWindowRect(FirstRect);

    FirstTileNumKey := 0;
    SecondTileNumKey := 0;
  end;

begin
  if IsTileNumKey(Key, TileNum) then
  begin
    HandleTileNumKey;
    Handled := True;
  end;
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
  UnselectedBrush: ID2D1SolidColorBrush;
  SelectedBrush: ID2D1SolidColorBrush;
  GrayBrush, BlackBrush: ID2D1SolidColorBrush;
  RT: ID2D1RenderTarget;
  TileNum, TileX, TileY: Integer;
  TextFormat: IDWriteTextFormat;

  procedure DrawTile(Rect: TRect);
  var
    TileText: string;
  begin
    RT.DrawRectangle(Rect, BlackBrush, 2);
    Rect.Inflate(-5, -5);

    RT.FillRectangle(Rect, UnselectedBrush);

    TileText := IntToStr(TileNum);

    RT.DrawText(PChar(TileText), Length(TileText), TextFormat, Rect, BlackBrush);
  end;

begin
  RT := DrawContext.RenderTarget;


  RT.CreateSolidColorBrush(D2D1ColorF(clGray), nil, GrayBrush);
  RT.CreateSolidColorBrush(D2D1ColorF(clBlack), nil, BlackBrush);
  RT.CreateSolidColorBrush(D2D1ColorF(clWhite), nil, SelectedBrush);
  RT.CreateSolidColorBrush(D2D1ColorF(clWhite, 0.8), nil, UnselectedBrush);
  DrawContext.DirectWriteFactory.CreateTextFormat('Arial', nil, DWRITE_FONT_WEIGHT_THIN,
    DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 96, 'de-de', TextFormat);
  TextFormat.SetTextAlignment(DWRITE_TEXT_ALIGNMENT_CENTER);
  TextFormat.SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);

  for TileNum := 1 to 9 do
    if IsTileNumToXYConvertible(TileNum, TileX, TileY) then
      DrawTile(RectGrid[TileX][TileY]);
end;

procedure TGridLayer.InvalidateMainContentResources;
begin

end;

end.
