unit WD.WindowPositioner;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Vcl.Forms,

  AnyiQuack,
  AQPSystemTypesAnimations,
  WindowEnumerator,
  WD.WindowTools,
  WD.Types;

type
  TWindowPositioner = class
  private
    type
    TWindowStack = TObjectStack<TWindow>;
    TStackDictionary = TObjectDictionary<HWND, TWindowStack>;
    TSubjectWindowStack = TObjectStack<TWindowStack>;

    class var
    WindowMoveAniID: Integer;

    var
    // Zuordnung zwischen einem Fensterhandle und dem Stapel mit den TWindow-Instanzen
    FStackDictionary: TStackDictionary;
    // Ein Aufruf von EnterWindow legt den zugeh�rigen Stapel mit den TWindow-Instanzen auf diesen
    // Stapel. Ein weiterer Aufruf von ExitWindow entfernt den letzten Eintrag von diesem Stapel.
    FCurrentStack: TSubjectWindowStack;
    FWindowsHandler: IWindowsHandler;

    function CurrentWindow: TWindow;
    procedure SetWindowPosInternal(Window: TWindow; TargetRect: TRect; Flags: Cardinal);

  public
    class constructor Create;
    constructor Create;
    destructor Destroy; override;

    procedure EnterWindow(WindowHandle: HWND);
    procedure MoveWindow(NewPos: TPoint);
    procedure PlaceWindow(NewPlace: TRect);
    procedure PopWindowPosition;
    procedure ExitWindow;

    procedure PushChangedWindowsPositions;

    property WindowsHandler: IWindowsHandler read FWindowsHandler write FWindowsHandler;
  end;

implementation

type
  TWindowLocal = class(TWindow)
  public
    // Die anf�ngliche Platzierung des Fensters, kann f�r die Wiederherstellung verwendet werden
    InitRect: TRect;
  end;

procedure UpdateWindowRect(W: TWindow);
var
  WL: TWindowLocal absolute W;
begin
  GetWindowRectDominaStyle(W.Handle, W.Rect);
  if WL.InitRect.IsEmpty then
    WL.InitRect := W.Rect;
end;

{ TWindowPositioner }

class constructor TWindowPositioner.Create;
begin
  WindowMoveAniID := TAQ.GetUniqueID;
end;

constructor TWindowPositioner.Create;
begin
  FStackDictionary := TStackDictionary.Create([doOwnsValues]);
  FCurrentStack := TSubjectWindowStack.Create(False);
end;

destructor TWindowPositioner.Destroy;
begin
  FStackDictionary.Free;
  FCurrentStack.Free;

  inherited Destroy;
end;

procedure TWindowPositioner.EnterWindow(WindowHandle: HWND);
var
  WinStack: TWindowStack;
  Window: TWindowLocal;
begin
  if not FStackDictionary.TryGetValue(WindowHandle, WinStack) then
  begin
    WinStack := TWindowStack.Create(True);
    Window := TWindowLocal.Create;
    Window.Handle := WindowHandle;
    UpdateWindowRect(Window);
    WinStack.Push(Window);
    FStackDictionary.Add(WindowHandle, WinStack);
  end;

  FCurrentStack.Push(WinStack);

  Take(CurrentWindow)
    .FinishAnimations(WindowMoveAniID);
end;

procedure TWindowPositioner.ExitWindow;
begin
  FCurrentStack.Pop;
end;

function TWindowPositioner.CurrentWindow: TWindow;
begin
  Result := FCurrentStack.Peek.Peek;
end;

procedure TWindowPositioner.SetWindowPosInternal(Window: TWindow; TargetRect: TRect;
  Flags: Cardinal);
var
  Placement: TWindowPlacement;
  WindowInfo: TWindowInfo;
  FromMonitor, TargetMonitor: TMonitor;
  MonitorWillChanged, AnimatedMovement: Boolean;

  function GetMonitorWillChanged: Boolean;
  begin
    Result := Screen.MonitorCount > 1;

    if Result then
    begin
      TargetMonitor := Screen.MonitorFromRect(TargetRect);
      Result := Assigned(FromMonitor) and Assigned(TargetMonitor) and
        (FromMonitor <> TargetMonitor);
    end;
  end;

begin
  // Ist ein Fenster aktuell maximiert, so wird es zuvor in den normalen Fenstermodus
  // wiederhergestellt
  Placement.length := SizeOf(Placement);
  if GetWindowPlacement(Window.Handle, Placement) and (Placement.showCmd = SW_SHOWMAXIMIZED) then
  begin
    Placement.showCmd := SW_RESTORE;
    SetWindowPlacement(Window.Handle, Placement);
    Sleep(250);
    UpdateWindowRect(Window);
  end;

  FromMonitor := Screen.MonitorFromRect(Window.Rect);
  TargetMonitor := nil;
  WindowInfo := GetWindowInfo(Window.Handle);

  MonitorWillChanged := GetMonitorWillChanged;

  // Animated movement between monitors with different DPI can makes different problems,
  // f.i. because the application must recalculate its layout and so breaks the movement.
  AnimatedMovement :=
    not MonitorWillChanged or
    (
      MonitorWillChanged and
      (
        (FromMonitor.PixelsPerInch = TargetMonitor.PixelsPerInch) or
        (WindowInfo.DPIAwareness = DPI_AWARENESS_PER_MONITOR_AWARE)
      )
    );

  if AnimatedMovement then
  begin
    Take(Window)
      .Plugin<TAQPSystemTypesAnimations>
      .RectAnimation(TargetRect,
        function(RefObject: TObject): TRect
        begin
          Result := TWindow(RefObject).Rect;
        end,
        procedure(RefObject: TObject; const NewRect: TRect)
        begin
          SetWindowPosDominaStyle(TWindow(RefObject).Handle, 0, NewRect, Flags);
        end,
        350, WindowMoveAniID, TAQ.Ease(TEaseType.etSinus));
  end
  else
    SetWindowPosDominaStyle(Window.Handle, 0, TargetRect, Flags);
end;

// Bewegt das aktuelle Fenster, unter Beibehaltung seiner aktuellen Gr��e, an die neue Stelle
procedure TWindowPositioner.MoveWindow(NewPos: TPoint);
var
  TargetRect: TRect;
  Window: TWindow;
begin
  Window := CurrentWindow;
  UpdateWindowRect(Window);
  TargetRect := Window.Rect;
  TargetRect.Location := NewPos;

  SetWindowPosInternal(Window, TargetRect, SWP_NOZORDER or SWP_NOSIZE or SWP_NOACTIVATE);
end;

// Platziert das aktuelle Fenster an eine neue Position, hierbei wird (wenn m�glich) auch die Gr��e
// des Fensters ver�ndert.
procedure TWindowPositioner.PlaceWindow(NewPlace: TRect);
var
  Window: TWindow;
begin
  Window := CurrentWindow;
  UpdateWindowRect(Window);

  SetWindowPosInternal(Window, NewPlace, SWP_NOZORDER or SWP_NOACTIVATE);
end;

// Stellt die zuletzt auf dem Stapel abgelegte Fensterposition f�r das aktuelle
// (mittels EnterWindow mitgeteilte) Fenser wieder her
procedure TWindowPositioner.PopWindowPosition;
var
  Window: TWindow;
  Stack: TWindowStack;
  FreeWindow: Boolean;
  CurRect: TRect;
begin
  Stack := FCurrentStack.Peek;
  GetWindowRectDominaStyle(CurrentWindow.Handle, CurRect);

  repeat
    FreeWindow := Stack.Count > 1;

    if FreeWindow then
      Window := Stack.Extract
    else
      Window := Stack.Peek;

    try
      if not SnapRect(CurRect, TWindowLocal(Window).InitRect) then
      begin
        PlaceWindow(TWindowLocal(Window).InitRect);
        if FreeWindow then
        begin
          FreeWindow := False;
          Stack.Push(Window);
        end;
        Exit;
      end;
    finally
      if FreeWindow then
        Window.Free;
    end;
  until not FreeWindow;
end;

// Soll FStackDictionary durchlaufen und schauen, ob sich der letzte Fenster-Status auf dem
// Stapel ver�ndert hat und wenn dies der Fall ist, dann einen neuen Eintrag auf dem Stapel
// erstellen
procedure TWindowPositioner.PushChangedWindowsPositions;

  procedure RemoveInvalidHandles;
  var
    WinHandle: HWND;
    InvalidHandles: TList<HWND>;
    CurWindowList: TWindowList;
  begin
    CurWindowList := FWindowsHandler.GetWindowList(wldDominaTargets);

    InvalidHandles := TList<HWND>.Create;
    try
      for WinHandle in FStackDictionary.Keys do
        if CurWindowList.IndexOf(WinHandle) < 0 then
          InvalidHandles.Add(WinHandle);

      for WinHandle in InvalidHandles do
        FStackDictionary.Remove(WinHandle);
    finally
      InvalidHandles.Free;
    end;
  end;

var
  Entry: TPair<HWND, TWindowStack>;
  CurWindow: TWindow;
  CurWindowLocal: TWindowLocal absolute CurWindow;
  NewWindow: TWindowLocal;
  CurRect: TRect;
begin
  // Zuerst ung�ltige Handles entfernen
  if Assigned(FWindowsHandler) then
    RemoveInvalidHandles;

  for Entry in FStackDictionary do
  begin
    CurWindow := Entry.Value.Peek;
    GetWindowRectDominaStyle(Entry.Key, CurRect);

    if not SnapRect(CurRect, CurWindowLocal.InitRect) then
    begin
      NewWindow := TWindowLocal.Create;
      NewWindow.Assign(CurWindow);
      NewWindow.InitRect := CurRect;
      Entry.Value.Push(NewWindow);
    end;
  end;
end;

end.
