unit WinDomina.Layer.Grid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
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
  TGridLayer = class(TBaseLayer)
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
  end;

implementation

{ TGridLayer }

constructor TGridLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkNumpad0, vkNumpad1, vkNumpad2, vkNumpad3, vkNumpad4, vkNumpad5,
    vkNumpad6, vkNumpad7, vkNumpad8, vkNumpad9]);
end;

procedure TGridLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TGridLayer.EnterLayer');
end;

procedure TGridLayer.ExitLayer;
begin
  AddLog('TGridLayer.ExitLayer');
  inherited ExitLayer;
end;

procedure TGridLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  procedure SizeWindowTile(TileX, TileY: Integer);
  var
    Window: THandle;
    Rect, WorkareaRect: TRect;
    WAWidth, WAHeight, TileWidth, TileHeight: Integer;
    LocalDominaWindows: TWindowList;
  begin
    LocalDominaWindows := DominaWindows;
    if LocalDominaWindows.Count = 0 then
      Exit;

    Window := LocalDominaWindows[0];
    WorkareaRect := GetWorkareaRect(Window);

    WAWidth := WorkareaRect.Width;
    WAHeight := WorkareaRect.Height;

    TileWidth := WAWidth div 3;
    TileHeight := WAHeight div 3;

    Rect.Left := WorkareaRect.Left + (TileX * TileWidth);
    Rect.Right := Rect.Left + TileWidth;
    Rect.Top := WorkareaRect.Top + (TileY * TileHeight);
    Rect.Bottom := Rect.Top + TileHeight;

    SetWindowPosDominaStyle(Window, 0, Rect, SWP_NOZORDER);
  end;

var
  TileX, TileY: Integer;
begin
  TileX := -1;
  TileY := -1;

  case Key of
    vkNumpad1:
    begin
      TileX := 0;
      TileY := 2;
    end;
    vkNumpad2:
    begin
      TileX := 1;
      TileY := 2;
    end;
    vkNumpad3:
    begin
      TileX := 2;
      TileY := 2;
    end;
    vkNumpad4:
    begin
      TileX := 0;
      TileY := 1;
    end;
    vkNumpad5:
    begin
      TileX := 1;
      TileY := 1;
    end;
    vkNumpad6:
    begin
      TileX := 2;
      TileY := 1;
    end;
    vkNumpad7:
    begin
      TileX := 0;
      TileY := 0;
    end;
    vkNumpad8:
    begin
      TileX := 1;
      TileY := 0;
    end;
    VK_NUMPAD9:
    begin
      TileX := 2;
      TileY := 0;
    end;
  end;

  if (TileX >= 0) or (TileY >= 0) then
  begin
    SizeWindowTile(TileX, TileY);
    Handled := True;
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
