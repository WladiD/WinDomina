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
begin
  FVisibleWindowList.Free;
  FVisibleWindowList := FWindowEnumerator.Enumerate;
  // Aktuell dominiertes Fenster aus der Liste entfernen
  FVisibleWindowList.Remove(DominaWindows[0]);
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
//    FastMode: Boolean;
//    FMStepX, FMStepY: Integer;
    WinRect, WorkareaRect, OverSizeRect: TRect;
    TestWin: TWindow;
    NewPos: TPoint;
    PosChanged: Boolean;

    procedure AdjustForFastModeStep(var TargetVar: Integer; Step: Integer);
    begin
      TargetVar := (TargetVar div Step) * Step;
    end;

    function RightToWinLeft(const R: TRect): Integer;
    begin
      Result := R.Right ;
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

      for TestWin in FVisibleWindowList do
      begin
        // An der rechten Kante andocken
        if (TestWin.Rect.Right >= WorkareaRect.Left) and (TestWin.Rect.Right < WinRect.Left) and
          (NewPos.X < TestWin.Rect.Right) then
          NewPos.X := TestWin.Rect.Right - (OverSizeRect.Right * 2)
        // An der linken Kante andocken
        else if (TestWin.Rect.Left >= WorkareaRect.Left) and (TestWin.Rect.Left < WinRect.Left) and
          (NewPos.X < TestWin.Rect.Left) then
          NewPos.X := TestWin.Rect.Left - (OverSizeRect.Left * 2);
      end;
    end
    else if DeltaX > 0 then // Nach rechts
    begin
      NewPos.X := WorkareaRect.Right + (OverSizeRect.Right * 2) + (Abs(OverSizeRect.Left) * 2) - WinRect.Width;
      NewPos.Y := WinRect.Top;

      for TestWin in FVisibleWindowList do
      begin
        if (TestWin.Rect.Left <= WorkareaRect.Right) and (WinRect.Right < TestWin.Rect.Left) and
          (NewPos.X > TestWin.Rect.Left) then
          NewPos.X := TestWin.Rect.Left - (OverSizeRect.Left * 2)
        else if (TestWin.Rect.Right <= WorkareaRect.Right) and (WinRect.Right < TestWin.Rect.Right) and
         (NewPos.X > TestWin.Rect.Right) then
          NewPos.X := TestWin.Rect.Right + Abs(OverSizeRect.Left) + OverSizeRect.Right - WinRect.Width;
      end;
    end
    else
      PosChanged := False;

    if PosChanged then
    begin
      WinRect.TopLeft := NewPos;
      SetWindowPosDominaStyle(Window, 0, WinRect, SWP_NOZORDER or SWP_NOSIZE);
//      SetWindowPos(Window, 0, NewPos.X, NewPos.Y, 0, 0, SWP_NOZORDER or SWP_NOSIZE);
    end;


//    FastMode := not WDMKeyStates.IsShiftKeyPressed;
//
//    if FastMode then
//    begin
//      FMStepX := (WorkareaRect.Width div 90);
//      FMStepY := (WorkareaRect.Height div 90);
//      DeltaX := DeltaX * FMStepX;
//      DeltaY := DeltaY * FMStepY;
//    end
//    else
//    begin
//      FMStepX := 0;
//      FMStepY := 0;
//    end;
//
//    if WDMKeyStates.IsControlKeyPressed then
//    begin
//      if FastMode then
//      begin
//        if DeltaX <> 0 then
//          AdjustForFastModeStep(WinRect.Right, FMStepX);
//        if DeltaY <> 0 then
//          AdjustForFastModeStep(WinRect.Bottom, FMStepY);
//      end;
//
//      Inc(WinRect.Right, DeltaX + -OverSizeRect.Right);
//      Inc(WinRect.Bottom, DeltaY + -OverSizeRect.Bottom);
//      SetWindowPos(Window, 0, 0, 0, WinRect.Width, WinRect.Height, SWP_NOZORDER or SWP_NOMOVE);
//    end
//    else
//    begin
//      if FastMode then
//      begin
//        if DeltaX <> 0 then
//          AdjustForFastModeStep(WinRect.Left, FMStepX);
//        if DeltaY <> 0 then
//          AdjustForFastModeStep(WinRect.Top, FMStepY);
//      end;
//
//      if (WinRect.Left <= WorkareaRect.Left) and FastMode and (DeltaX < 0) then
//        WinRect.Left := WorkareaRect.Left + OverSizeRect.Left
//      else
//        Inc(WinRect.Left, DeltaX + -OverSizeRect.Left);
//
//      if (WinRect.Top <= WorkareaRect.Top) and FastMode and (DeltaY < 0) then
//        WinRect.Top := WorkareaRect.Top + OverSizeRect.Top
//      else
//        Inc(WinRect.Top, DeltaY + -OverSizeRect.Top);
//
//      SetWindowPos(Window, 0, WinRect.Left, WinRect.Top, 0, 0, SWP_NOZORDER or SWP_NOSIZE);
//    end;
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
