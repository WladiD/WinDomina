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
    WinRect, TestRect, WorkareaRect: TRect;
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

    // Sagt aus, ob der absolute Unterschied zwischen den beiden Parametern
    // eine Mindestdifferenz erfüllt
    function DiffSnap(A, B: Integer): Boolean;
    const
      MinDiff = 5;
    begin
      Result := Abs(A - B) >= MinDiff;
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
          TestRect := TestWin.Rect;
          // Rechte Kante
          if (TestRect.Right >= WorkareaRect.Left) and (TestRect.Right < WinRect.Left) and
            (NewPos.X < TestRect.Right) and DiffSnap(TestRect.Right, WinRect.Left) then
            NewPos.X := TestRect.Right
          // Linke Kante
          else if (TestRect.Left >= WorkareaRect.Left) and (TestRect.Left < WinRect.Left) and
            (NewPos.X < TestRect.Left) and DiffSnap(TestRect.Left, WinRect.Left) then
            NewPos.X := TestRect.Left;
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
          TestRect := TestWin.Rect;
          // Linke Kante
          if (TestRect.Left <= WorkareaRect.Right) and (TestRect.Left > WinRect.Right) and
            (NewPos.X > (TestRect.Left - WinRect.Width)) and
            DiffSnap(TestRect.Left, WinRect.Right) then
            NewPos.X := TestRect.Left - WinRect.Width
          // Rechte Kante
          else if (TestRect.Right <= WorkareaRect.Right) and (TestRect.Right > WinRect.Right) and
           (NewPos.X > (TestRect.Right - WinRect.Width)) and
           DiffSnap(TestRect.Right, WinRect.Right) then
            NewPos.X := TestRect.Right - WinRect.Width;
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
          TestRect := TestWin.Rect;
          // Untere Kante
          if (TestRect.Bottom >= WorkareaRect.Top) and (TestRect.Bottom < WinRect.Top) and
            (NewPos.Y < TestRect.Bottom) and DiffSnap(TestRect.Bottom, WinRect.Top) then
            NewPos.Y := TestRect.Bottom
          // Obere Kante
          else if (TestRect.Top >= WorkareaRect.Top) and (TestRect.Top < WinRect.Top) and
            (NewPos.Y < TestRect.Top) and DiffSnap(TestRect.Top, WinRect.Top) then
            NewPos.Y := TestRect.Top;
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
          TestRect := TestWin.Rect;
          // Obere Kante
          if (TestRect.Top <= WorkareaRect.Bottom) and (WinRect.Bottom < TestRect.Top) and
            (NewPos.Y > (TestRect.Top - WinRect.Height)) and
            DiffSnap(WinRect.Bottom, TestRect.Top) then
            NewPos.Y := TestRect.Top - WinRect.Height
          // Untere Kante
          else if (TestRect.Bottom <= WorkareaRect.Bottom) and (WinRect.Bottom < TestRect.Bottom) and
           (NewPos.Y > (TestRect.Bottom - WinRect.Height)) and
           DiffSnap(WinRect.Bottom, TestRect.Bottom) then
            NewPos.Y := TestRect.Bottom - WinRect.Height;
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
