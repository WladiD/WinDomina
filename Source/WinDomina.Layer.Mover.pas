unit WinDomina.Layer.Mover;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  Winapi.Windows,

  WindowEnumerator,

  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools;

type
  TMoverLayer = class(TBaseLayer)
  private
    FWindowEnumerator: TWindowEnumerator;
    FVisibleWindowList: TWindowList;

    procedure UpdateVisibleWindowList;

  public
    constructor Create; override;
    destructor Destroy; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;
  end;

implementation

{ TMoverLayer }

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkM]);

  FWindowEnumerator := TWindowEnumerator.Create;
  FWindowEnumerator.RequiredWindowInfos := [wiRect];
  FWindowEnumerator.IncludeMask := WS_CAPTION or WS_VISIBLE;
  FWindowEnumerator.ExcludeMask := WS_DISABLED;
  FWindowEnumerator.VirtualDesktopFilter := True;
  FWindowEnumerator.OverlappedWindowsFilter := True;
  FWindowEnumerator.CloakedWindowsFilter := True;
  FWindowEnumerator.GetWindowRectFunction :=
    function(WindowHandle: HWND): TRect
    begin
      if not GetWindowRectDominaStyle(WindowHandle, Result) then
        Result := TRect.Empty;
    end;
end;

destructor TMoverLayer.Destroy;
begin
  FWindowEnumerator.Free;
  FVisibleWindowList.Free;

  inherited Destroy;
end;

procedure TMoverLayer.UpdateVisibleWindowList;
var
  LogWinHandle: HWND;
begin
  FVisibleWindowList.Free;
  FVisibleWindowList := FWindowEnumerator.Enumerate;
  // Aktuell dominiertes Fenster aus der Liste entfernen
  FVisibleWindowList.Remove(DominaWindows[0]);
  if Logging.HasWindowHandle(LogWinHandle) then
    FVisibleWindowList.Remove(LogWinHandle);
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TMoverLayer.EnterLayer');
end;

procedure TMoverLayer.ExitLayer;
begin
  AddLog('TMoverLayer.ExitLayer');
  inherited ExitLayer;
end;

procedure TMoverLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  procedure MoveSizeWindow(DeltaX, DeltaY: Integer);
  var
    Window: THandle;
    WinRect, WorkareaRect, OverSizeRect: TRect;
    TestWin: TWindow;
    NewPos: TPoint;
    PosChanged: Boolean;
    Center: Integer;

    procedure AdjustForFastModeStep(var TargetVar: Integer; Step: Integer);
    begin
      TargetVar := (TargetVar div Step) * Step;
    end;

    function CalcXCenter: Integer;
    begin
      Result := (WorkareaRect.Width - WinRect.Width) div 2;
    end;

    function CalcYCenter: Integer;
    begin
      Result := (WorkareaRect.Height - WinRect.Height) div 2;
    end;

  begin
    if DominaWindows.Count = 0 then
      Exit;

    Window := DominaWindows[0];
    GetWindowRect(Window, WinRect);
//    LogMemo.Lines.Add('GetWindowRect: ' + RectToString(WinRect));
    WorkareaRect := GetWorkareaRect(WinRect);
    GetWindowRectDominaStyle(Window, WinRect);
//    LogMemo.Lines.Add('GetWindowRectDominaStyle: ' + RectToString(WinRect));
    OverSizeRect := GetWindowNonClientOversize(Window);

    UpdateVisibleWindowList;
    NewPos := TPoint.Zero;
    PosChanged := True;

    if DeltaX < 0 then // Nach links
    begin
      NewPos.X := WorkareaRect.Left;
      NewPos.Y := WinRect.Top;

      if FVisibleWindowList.Count = 0 then
      begin
        Center := CalcXCenter;
        if WinRect.Left > Center then
          NewPos.X := Center;
      end
      else
      begin
        for TestWin in FVisibleWindowList do
        begin
          // Rechte Kante
          if (TestWin.Rect.Right >= WorkareaRect.Left) and (TestWin.Rect.Right < WinRect.Left) and
            (NewPos.X < TestWin.Rect.Right) then
            NewPos.X := TestWin.Rect.Right
          // Linke Kante
          else if (TestWin.Rect.Left >= WorkareaRect.Left) and (TestWin.Rect.Left < WinRect.Left) and
            (NewPos.X < TestWin.Rect.Left) then
            NewPos.X := TestWin.Rect.Left;
        end;
      end;
    end
    else if DeltaX > 0 then // Nach rechts
    begin
      NewPos.X := WorkareaRect.Right - WinRect.Width;
      NewPos.Y := WinRect.Top;

      if FVisibleWindowList.Count = 0 then
      begin
        Center := CalcXCenter;
        if WinRect.Left < Center then
          NewPos.X := Center;
      end
      else
      begin
        for TestWin in FVisibleWindowList do
        begin
          // Linke Kante
          if (TestWin.Rect.Left <= WorkareaRect.Right) and (WinRect.Right < TestWin.Rect.Left) and
            (NewPos.X > TestWin.Rect.Left) then
            NewPos.X := TestWin.Rect.Left
          // Rechte Kante
          else if (TestWin.Rect.Right <= WorkareaRect.Right) and (WinRect.Right < TestWin.Rect.Right) and
           (NewPos.X > (TestWin.Rect.Right - WinRect.Width)) then
            NewPos.X := TestWin.Rect.Right - WinRect.Width;
        end;
      end;
    end
    else if DeltaY < 0 then // Nach oben
    begin
      NewPos.X := WinRect.Left;
      NewPos.Y := WorkareaRect.Top;

      if FVisibleWindowList.Count = 0 then
      begin
        Center := CalcYCenter;
        if WinRect.Top > Center then
          NewPos.Y := Center;
      end
      else
      begin
        for TestWin in FVisibleWindowList do
        begin
          // Untere Kante
          if (TestWin.Rect.Bottom >= WorkareaRect.Top) and (TestWin.Rect.Bottom < WinRect.Top) and
            (NewPos.Y < TestWin.Rect.Bottom) then
            NewPos.Y := TestWin.Rect.Bottom
          // Obere Kante
          else if (TestWin.Rect.Top >= WorkareaRect.Top) and (TestWin.Rect.Top < WinRect.Top) and
            (NewPos.Y < TestWin.Rect.Top) then
            NewPos.Y := TestWin.Rect.Top;
        end;
      end;
    end
    else if DeltaY > 0 then // Nach unten
    begin
      NewPos.X := WinRect.Left;
      NewPos.Y := WorkareaRect.Bottom - WinRect.Height;

      if FVisibleWindowList.Count = 0 then
      begin
        Center := CalcYCenter;
        if WinRect.Top < Center then
          NewPos.Y := Center;
      end
      else
      begin
        for TestWin in FVisibleWindowList do
        begin
          // Obere Kante
          if (TestWin.Rect.Top <= WorkareaRect.Bottom) and (WinRect.Bottom < TestWin.Rect.Top) and
            (NewPos.Y > TestWin.Rect.Top) then
            NewPos.Y := TestWin.Rect.Top
          // Untere Kante
          else if (TestWin.Rect.Bottom <= WorkareaRect.Bottom) and (WinRect.Bottom < TestWin.Rect.Bottom) and
           (NewPos.Y > (TestWin.Rect.Bottom - WinRect.Height)) then
            NewPos.Y := TestWin.Rect.Bottom - WinRect.Height;
        end;
      end;
    end
    else
      PosChanged := False;

    if PosChanged then
    begin
      WinRect.TopLeft := NewPos;
      SetWindowPosDominaStyle(Window, 0, WinRect, SWP_NOZORDER or SWP_NOSIZE);
    end;
  end;

var
  DeltaX, DeltaY: Integer;
begin
  DeltaX := 0;
  DeltaY := 0;

  case Key of
    vkLeft:
      DeltaX := -1;
    VK_RIGHT:
      DeltaX := 1;
    VK_UP:
      DeltaY := -1;
    VK_DOWN:
      DeltaY := 1;
  end;

  if (DeltaX <> 0) or (DeltaY <> 0) then
  begin
    MoveSizeWindow(DeltaX, DeltaY);
    Handled := True;
  end;
end;

procedure TMoverLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

end.
