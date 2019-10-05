unit WinDomina.Form.Main;

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.UITypes,
  System.Win.ComObj,
  System.ImageList,
  System.Actions,
  System.Math,
  System.StrUtils,
  System.Diagnostics,
  System.SyncObjs,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.Menus,
  Vcl.ActnList,

  GR32,
  GR32_Backends,
  AnyiQuack,
  Localization,
  SendInputHelper,
  WindowEnumerator,

  WinDomina.Types,
  WinDomina.Types.Messages,
  WinDomina.WindowTools,
  WinDomina.WindowPositioner,
  WinDomina.Registry,
  WinDomina.Layer,
  WinDomina.KBHKLib,
  WinDomina.Form.Log;

type
  TUpdateWindowThread = class;

  TMainForm = class(TForm, ITranslate, IMonitorHandler, IWindowsHandler)
    TrayIcon: TTrayIcon;
    TrayImageList: TImageList;
    TrayPopupMenu: TPopupMenu;
    ActionList: TActionList;
    CloseAction: TAction;
    CloseMenuItem: TMenuItem;
    ToggleDominaModeAction: TAction;
    ToggleDominaModeMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CloseActionExecute(Sender: TObject);
    procedure ToggleDominaModeActionExecute(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  private
    type
    TDomainWindowList = TObjectDictionary<TWindowListDomain, TWindowList>;

    class var
    UpdateWindowWorkareaDelayID: Integer;
    PushChangedWindowsPositionsDelayID: Integer;
    TargetWindowListenerIntervalID: Integer;

    var
    FVisible: Boolean;
    FLayers: TLayerList;
    FActiveLayers: TLayerList;
    FLastUsedLayer: TBaseLayer;
    FWindowList: TDomainWindowList;
    FMainBitmap: TBitmap32;
    FUpdateWindowThread: TUpdateWindowThread;

    procedure AddLayer(Layer: TBaseLayer);
    function GetActiveLayer: TBaseLayer;
    function HasActiveLayer(out Layer: TBaseLayer): Boolean;
    procedure EnterLayer(Layer: TBaseLayer);
    procedure ExitLayer;
    procedure LayerMainContentChanged(Sender: TObject);

    procedure LogWindow(Window: THandle);

    procedure WD_EnterDominaMode(var Message: TMessage); message WD_ENTER_DOMINA_MODE;
    procedure WD_ExitDominaMode(var Message: TMessage); message WD_EXIT_DOMINA_MODE;
    procedure WD_KeyDownDominaMode(var Message: TMessage); message WD_KEYDOWN_DOMINA_MODE;
    procedure WD_KeyUpDominaMode(var Message: TMessage); message WD_KEYUP_DOMINA_MODE;
    procedure DominaModeChanged;

    procedure AdjustWindowWorkarea(Workarea: TRect);
    procedure AdjustWindowWorkareaFromPoint(Point: TPoint);
    procedure AdjustWindowWorkareaFromMonitor(Monitor: TMonitor);
    procedure UpdateWindowWorkarea;
    procedure UpdateWindowWorkareaDelayed(Delay: Integer);
    procedure RenderWindowContent;
    procedure ClearWindowContent;

    property MainBitmap: TBitmap32 read FMainBitmap;

  private
    FPrevTargetWindow: TWindow;

    procedure StartTargetWindowListener;
    procedure CheckTargetWindow;
    procedure StopTargetWindowListener;
    procedure DoTargetWindowChanged(PrevTargetWindowHandle, NewTargetWindowHandle: HWND);
    procedure DoTargetWindowMoved;

  // ITranslate-Interface
  private
    function IsReadyForTranslate: Boolean;
    procedure OnReadyForTranslate(NotifyEvent: TNotifyEvent);
    procedure Translate;

  // IMonitorHandler-Interface
  private
    function HasAdjacentMonitor(Direction: TDirection; out AdjacentMonitor: TMonitor): Boolean;
    function HasNextMonitor(out Monitor: TMonitor): Boolean;
    function HasPrevMonitor(out Monitor: TMonitor): Boolean;

    function ClientToScreen(const Rect: TRect): TRect; overload;
    function ScreenToClient(const Rect: TRect): TRect; overload;

    function GetCurrentMonitor: TMonitor;
    procedure SetCurrentMonitor(Monitor: TMonitor);

  // IWindowsHandler-Interface
  private
    function CreateWindowList(Domain: TWindowListDomain): TWindowList;
    procedure UpdateWindowList(Domain: TWindowListDomain);
    function GetWindowList(Domain: TWindowListDomain): TWindowList;

  public
    class constructor Create;
  end;

  TUpdateWindowThread = class(TThread)
  protected
    UpdateWindowEvent: TEvent;
    Bitmap: TBitmap32;
    WindowHandle: HWND;
    ContentValid: Boolean;

    procedure TerminatedSet; override;
    procedure Execute; override;
  public
    constructor Create;

    procedure RequestUpdateWindow;
  end;

var
  MainForm: TMainForm;

implementation

uses
  WinDomina.Layer.Grid,
  WinDomina.Layer.Mover;

{$R *.dfm}

{ TMainForm }

class constructor TMainForm.Create;
begin
  UpdateWindowWorkareaDelayID := TAQ.GetUniqueID;
  TargetWindowListenerIntervalID := TAQ.GetUniqueID;
  PushChangedWindowsPositionsDelayID := TAQ.GetUniqueID;
end;

procedure TMainForm.FormCreate(Sender: TObject);

  function CreateLayer(LayerClass: TBaseLayerClass): TBaseLayer;
  begin
    Result := LayerClass.Create;
    Result.MonitorHandler := Self;
    Result.WindowsHandler := Self;
    Result.OnMainContentChanged := LayerMainContentChanged;
  end;

  procedure AddLayers;
  begin
    AddLayer(CreateLayer(TMoverLayer));
    AddLayer(CreateLayer(TGridLayer));
  end;

  function CreateWindowPositioner: TWindowPositioner;
  begin
    Result := TWindowPositioner.Create;
    Result.WindowsHandler := Self;
  end;

var
  ExStyle: DWORD;
  Logger: TStringsLogging;
begin
  LogForm := TLogForm.Create(Self);
  Logger := TStringsLogging.Create(LogForm.LogMemo.Lines);
  Logger.WindowHandle := LogForm.Handle;
  RegisterLogging(Logger);

  ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
  if (ExStyle and WS_EX_LAYERED) = 0 then
    SetWindowLong(Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);

  FWindowList := TDomainWindowList.Create([doOwnsValues]);
  FLayers := TLayerList.Create(True);
  FActiveLayers := TLayerList.Create(False);
  FPrevTargetWindow := TWindow.Create;
  RegisterWDMKeyStates(TKeyStates.Create);
  RegisterLayerActivationKeys(TKeyLayerList.Create);
  RegisterWindowPositioner(CreateWindowPositioner);

  AddLayers;

  // Initialisierung der RuntimeInfo
  RuntimeInfo.DefaultPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  RuntimeInfo.CommonPath := IncludeTrailingPathDelimiter(RuntimeInfo.DefaultPath + 'common');

  InstallHook(Handle);

  FMainBitmap := TBitmap32.Create;
  FUpdateWindowThread := TUpdateWindowThread.Create;
  FUpdateWindowThread.WindowHandle := Handle;
  FUpdateWindowThread.Bitmap := FMainBitmap;

  InitializeLang(RuntimeInfo.CommonPath);

  Take(Self)
    .EachDelay(1000,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        TrayIcon.ShowBalloonHint;
        Result := True;
      end);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FActiveLayers.Free;
  FLayers.Free;
  FWindowList.Free;
  FPrevTargetWindow.Free;
  FMainBitmap.Free;
  FUpdateWindowThread.Free;

  UninstallHook;
end;

function TMainForm.IsReadyForTranslate: Boolean;
begin
  Result := True;
end;

procedure TMainForm.OnReadyForTranslate(NotifyEvent: TNotifyEvent);
begin

end;

procedure TMainForm.Translate;
begin
  TrayIcon.BalloonTitle := Lang[2]; // Dominate-Modus aktivieren
  TrayIcon.BalloonHint := Lang[4]; // Tippen Sie doppelt auf die CapsLock-Taste (Feststelltaste) um den Dominate-Modus zu aktivieren

  // Weil es dort statusabhängige Übersetzungen geben kann
  DominaModeChanged;
end;

function HasMonitorIndex(Monitor: TMonitor; out MonitorIndex: Integer): Boolean;
var
  cc: Integer;
begin
  Result := True;
  for cc := 0 to Screen.MonitorCount - 1 do
    if Monitor = Screen.Monitors[cc] then
    begin
      MonitorIndex := cc;
      Exit;
    end;
  Result := False;
end;

function TMainForm.HasAdjacentMonitor(Direction: TDirection; out AdjacentMonitor: TMonitor): Boolean;
var
  CurMonitorIndex: Integer;
  CurBounds: TRect;
  cc: Integer;
  TestMonitor: TMonitor;
begin
  Result := (Screen.MonitorCount > 1) and HasMonitorIndex(Monitor, CurMonitorIndex);
  if not Result then
    Exit;

  CurBounds := Monitor.BoundsRect;

  for cc := 0 to Screen.MonitorCount - 1 do
  begin
    if cc = CurMonitorIndex then
      Continue;

    TestMonitor := Screen.Monitors[cc];
    if
      (
        (Direction = dirLeft) and
        Snap(CurBounds.Left, TestMonitor.BoundsRect.Right)
      ) or
      (
        (Direction = dirRight) and
        Snap(CurBounds.Right, TestMonitor.BoundsRect.Left)
      ) or
      (
        (Direction = dirUp) and
        Snap(CurBounds.Top, TestMonitor.BoundsRect.Bottom)
      ) or
      (
        (Direction = dirDown) and
        Snap(CurBounds.Bottom, TestMonitor.BoundsRect.Top)
      ) then
    begin
      AdjacentMonitor := TestMonitor;
      Exit;
    end;
  end;

  Result := False;
end;

function TMainForm.HasNextMonitor(out Monitor: TMonitor): Boolean;
var
  MonitorIndex: Integer;
begin
  Result := (Screen.MonitorCount > 1) and HasMonitorIndex(Self.Monitor, MonitorIndex);
  if not Result then
    Exit;

  Inc(MonitorIndex);
  if MonitorIndex >= Screen.MonitorCount then
    MonitorIndex := 0;

  Monitor := Screen.Monitors[MonitorIndex];
end;

function TMainForm.HasPrevMonitor(out Monitor: TMonitor): Boolean;
var
  MonitorIndex: Integer;
begin
  Result := (Screen.MonitorCount > 1) and HasMonitorIndex(Self.Monitor, MonitorIndex);
  if not Result then
    Exit;

  Dec(MonitorIndex);
  if MonitorIndex < 0 then
    MonitorIndex := Screen.MonitorCount - 1;

  Monitor := Screen.Monitors[MonitorIndex];
end;

function TMainForm.ClientToScreen(const Rect: TRect): TRect;
begin
  Result.TopLeft := ClientToScreen(Rect.TopLeft);
  Result.Width := Rect.Width;
  Result.Height := Rect.Height;
end;

function TMainForm.ScreenToClient(const Rect: TRect): TRect;
begin
  Result.TopLeft := ScreenToClient(Rect.TopLeft);
  Result.Width := Rect.Width;
  Result.Height := Rect.Height;
end;

function TMainForm.GetCurrentMonitor: TMonitor;
begin
  Result := Monitor;
end;

procedure TMainForm.SetCurrentMonitor(Monitor: TMonitor);
begin
  AdjustWindowWorkareaFromMonitor(Monitor);
end;

function TMainForm.CreateWindowList(Domain: TWindowListDomain): TWindowList;

  function CreateWindowEnumerator: TWindowEnumerator;
  begin
    Result := TWindowEnumerator.Create;
    Result.GetWindowRectFunction :=
      function(WindowHandle: HWND): TRect
      begin
        if not GetWindowRectDominaStyle(WindowHandle, Result) then
          Result := TRect.Empty;
      end;
    Result.GetCurrentMonitorFunction :=
      function: TMonitor
      begin
        Result := Monitor;
      end;

    Result.RequiredWindowInfos := [wiRect];
    Result.IncludeMask := WS_CAPTION or WS_VISIBLE;
    Result.ExcludeMask := WS_DISABLED;
    Result.CloakedWindowsFilter := True;
    Result.VirtualDesktopFilter := True;
    Result.HiddenWindowsFilter := True;

    case Domain of
      wldDominaTargets:
      begin
        // Ohne diesen Filter wird jedes Vordergrundfenster, unabhängig davon ob es aktiv ist oder
        // nicht, zum Zielfenster. Daher müssen alle Vordergrundfenster, die nicht aktiv sind
        // ausgefiltert werden.
        Result.InactiveTopMostWindowsFilter := True;
      end;
      wldAlignTargets:
      begin
        Result.OverlappedWindowsFilter := True;
        Result.MonitorFilter := True;
      end;
      wldSwitchTargets:
      begin
        Result.MonitorFilter := True;
      end;
    end;
  end;

var
  WinEnumerator: TWindowEnumerator;
  TempHandle: HWND;
begin
  WinEnumerator := CreateWindowEnumerator;
  try
    Result := WinEnumerator.Enumerate;
  finally
    WinEnumerator.Free;
  end;

  if Domain = wldDominaTargets then
  begin
    if Logging.HasWindowHandle(TempHandle) then
      Result.Remove(TempHandle);
  end;

  FWindowList.AddOrSetValue(Domain, Result.Clone);
end;

procedure TMainForm.UpdateWindowList(Domain: TWindowListDomain);
begin
  FWindowList.AddOrSetValue(Domain, CreateWindowList(Domain));
end;

function TMainForm.GetWindowList(Domain: TWindowListDomain): TWindowList;
begin
  if not FWindowList.TryGetValue(Domain, Result) then
  begin
    UpdateWindowList(Domain);
    if not FWindowList.TryGetValue(Domain, Result) then
      raise Exception.CreateFmt('WindowList for Domain %d could not be updated', [Ord(Domain)]);
  end;
end;

procedure TMainForm.ToggleDominaModeActionExecute(Sender: TObject);
begin
  ToggleDominaMode;
end;

procedure TMainForm.TrayIconDblClick(Sender: TObject);
begin
  ToggleDominaModeAction.Execute;
end;

// Passt das Fenster an die übergebene Arbeitsfläche an und setzt es in den Vordergrund
procedure TMainForm.AdjustWindowWorkarea(Workarea: TRect);
begin
  if not (FVisible or (BoundsRect <> Workarea)) then
    Exit;

  MainBitmap.Lock;
  try
    SetWindowPos(Handle, HWND_TOPMOST, Workarea.Left, Workarea.Top, Workarea.Width, Workarea.Height,
      SWP_SHOWWINDOW or SWP_NOACTIVATE {or SWP_NOSIZE or SWP_NOMOVE});
    UpdateBoundsRect(Workarea);
    MainBitmap.SetSize(Workarea.Width, Workarea.Height);
  finally
    MainBitmap.Unlock;
  end;

  RenderWindowContent;
end;

procedure TMainForm.AdjustWindowWorkareaFromPoint(Point: TPoint);
begin
  AdjustWindowWorkareaFromMonitor(Screen.MonitorFromPoint(Point));
end;

procedure TMainForm.AdjustWindowWorkareaFromMonitor(Monitor: TMonitor);
begin
  if Assigned(Monitor) then
    AdjustWindowWorkarea(Monitor.WorkareaRect);
end;

// Aktualisiert die Position dieses Forms auf die Arbeitsfläche des Monitors auf dem sich das
// aktuelle Fenster befindet. Wenn kein Zielfenster vorhanden ist, so wird die Position des
// Mauscursors verwendet.
procedure TMainForm.UpdateWindowWorkarea;
var
  TargetWindow: TWindow;
begin
  if GetWindowList(wldDominaTargets).HasFirst(TargetWindow) then
    AdjustWindowWorkareaFromMonitor(Screen.MonitorFromRect(TargetWindow.Rect))
  else
    AdjustWindowWorkareaFromPoint(Mouse.CursorPos);
end;

procedure TMainForm.UpdateWindowWorkareaDelayed(Delay: Integer);
begin
  Take(Self)
    .CancelDelays(UpdateWindowWorkareaDelayID)
    .EachDelay(Delay,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        UpdateWindowWorkarea;
        Result := False;
      end, UpdateWindowWorkareaDelayID);
end;

procedure TMainForm.StartTargetWindowListener;
begin
  Take(Self)
    .CancelIntervals(TargetWindowListenerIntervalID)
    .EachInterval(100,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        CheckTargetWindow;
        Result := False;
      end, TargetWindowListenerIntervalID);
end;

procedure TMainForm.CheckTargetWindow;
var
  TargetWindow: TWindow;
begin
  UpdateWindowList(wldDominaTargets);
  if not GetWindowList(wldDominaTargets).HasFirst(TargetWindow) then
    Exit;

  if TargetWindow.Handle <> FPrevTargetWindow.Handle then
    DoTargetWindowChanged(FPrevTargetWindow.Handle, TargetWindow.Handle)
  else if TargetWindow.Rect <> FPrevTargetWindow.Rect then
    DoTargetWindowMoved;

  FPrevTargetWindow.Assign(TargetWindow);
end;

procedure TMainForm.StopTargetWindowListener;
begin
  Take(Self)
    .CancelIntervals(TargetWindowListenerIntervalID);
  FPrevTargetWindow.Handle := 0;
  FPrevTargetWindow.Rect := TRect.Empty;
end;

// Sollte aufgerufen werden, wenn sich das Zielfenster verändert
procedure TMainForm.DoTargetWindowChanged(PrevTargetWindowHandle, NewTargetWindowHandle: HWND);
begin
  UpdateWindowWorkareaDelayed(500);
  GetActiveLayer.TargetWindowChanged;

  // Damit die Position des Zielfensters im Positioner erfasst wird
  WindowPositioner.EnterWindow(NewTargetWindowHandle);
  WindowPositioner.ExitWindow;
end;

// Sollte aufgerufen werden, wenn sich die Position des Zielfenster ändert
procedure TMainForm.DoTargetWindowMoved;
begin
  UpdateWindowWorkareaDelayed(500);
  GetActiveLayer.TargetWindowMoved;

  // Die geänderte Position des Fensters soll verzögert auch im Positionierungsstack erfasst werden
  Take(Self)
    .CancelDelays(PushChangedWindowsPositionsDelayID)
    .EachDelay(750,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        WindowPositioner.PushChangedWindowsPositions;
        Result := False;
      end, PushChangedWindowsPositionsDelayID);
end;

procedure TMainForm.RenderWindowContent;
{.$DEFINE BOTTLENECK_LOG}
var
  Layer: TBaseLayer;
{$IFDEF BOTTLENECK_LOG}
  WholeStopper, BottleneckStopper: TStopwatch;
{$ENDIF}
begin
{$IFDEF BOTTLENECK_LOG}
  WholeStopper := TStopwatch.StartNew;
{$ENDIF}

  MainBitmap.Lock;
  try
    if HasActiveLayer(Layer) and Layer.HasMainContent then
    begin
{$IFDEF BOTTLENECK_LOG}
      BottleneckStopper := TStopwatch.StartNew;
{$ENDIF}

      Layer.RenderMainContent(MainBitmap);

{$IFDEF BOTTLENECK_LOG}
      BottleneckStopper.Stop;
      Logging.AddLog('Dauer RenderMainContent ' + BottleneckStopper.ElapsedMilliseconds.ToString + ' msec.');
{$ENDIF}
    end;

    FUpdateWindowThread.RequestUpdateWindow;
  finally
    MainBitmap.Unlock;
  end;

{$IFDEF BOTTLENECK_LOG}
  WholeStopper.Stop;
  Logging.AddLog('Dauer kompletter RenderWindowContent ' + WholeStopper.ElapsedMilliseconds.ToString + ' msec.');
  Logging.AddLog('---');
{$ENDIF}
end;

// Leert das Bitmap für das Layer-Window
//
// Wird beim Exit des Domina-Modus aufgerufen, weil sonst beim nächsten Start des Domina-Modus
// für einen kurzen Moment der vorherige Inhalt sichtbar ist sein kann.
procedure TMainForm.ClearWindowContent;
begin
  MainBitmap.Lock;
  try
    MainBitmap.Clear(Color32(0, 0, 0, 0));
    FUpdateWindowThread.RequestUpdateWindow;
  finally
    MainBitmap.Unlock;
  end;
end;

procedure TMainForm.CloseActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.AddLayer(Layer: TBaseLayer);
begin
  FLayers.Add(Layer);
end;

function TMainForm.GetActiveLayer: TBaseLayer;
begin
  Result := FActiveLayers.First;
end;

function TMainForm.HasActiveLayer(out Layer: TBaseLayer): Boolean;
begin
  Result := FActiveLayers.Count > 0;
  if Result then
    Layer := FActiveLayers.First;
end;

procedure TMainForm.EnterLayer(Layer: TBaseLayer);
var
  LayerIndex: Integer;
  CurLayer: TBaseLayer;
begin
  if FActiveLayers.Count > 0 then
  begin
    CurLayer := GetActiveLayer;
    if CurLayer.IsLayerActive and (CurLayer <> Layer) then
      CurLayer.ExitLayer;
  end;

  LayerIndex := FActiveLayers.IndexOf(Layer);

  if LayerIndex > 0 then
    FActiveLayers.Exchange(LayerIndex, 0)
  else if LayerIndex = -1 then
    FActiveLayers.Insert(0, Layer);

  if not Layer.IsLayerActive then
  begin
    Caption := Lang[0] + ': ' + Layer.GetDisplayName;
    Layer.EnterLayer;
    RenderWindowContent;
  end;
end;

procedure TMainForm.ExitLayer;
var
  CurLayer: TBaseLayer;
begin
  if FActiveLayers.Count > 0 then
  begin
    CurLayer := GetActiveLayer;
    if CurLayer.IsLayerActive then
      CurLayer.ExitLayer;
  end;
end;

procedure TMainForm.LayerMainContentChanged(Sender: TObject);
begin
  RenderWindowContent;
end;

procedure TMainForm.LogWindow(Window: THandle);

  function GetLogString(ForWin: THandle): string;
  var
    St: array [0..256] of Char;
    Rect: TRect;
  begin
    GetWindowRect(ForWin, Rect);
    GetWindowText(ForWin, St, SizeOf(St));
    Result := Format('%d, %d - %d, %d; Title: %s; Handle: %d',
      [Rect.Left, Rect.Top, Rect.Width, Rect.Height, St, ForWin]);
  end;

begin
  AddLog(GetLogString(Window));
//  AddLog('-- GetAncestor(Window, GA_PARENT): ' + GetLogString(GetAncestor(Window, GA_PARENT)));
//  AddLog('-- GetAncestor(Window, GA_ROOT): ' + GetLogString(GetAncestor(Window, GA_ROOT)));
//  AddLog('-- GetAncestor(Window, GA_ROOTOWNER): ' + GetLogString(GetAncestor(Window, GA_ROOTOWNER)));
  AddLog('-- Style: ' + WindowStyleToString(GetWindowLong(Window, GWL_STYLE)));
end;

var
  EnumFoundWindow: THandle;

function EnumNotifyWinProc(Wnd: THandle): Boolean; stdcall;
begin
  if IsWindowVisible(Wnd) then
  begin
    EnumFoundWindow := Wnd;
    MainForm.LogWindow(Wnd);
  end;
  Result := True;
end;

procedure TMainForm.WD_EnterDominaMode(var Message: TMessage);

  function HasParentWindow(Window: HWND; out ParentWindow: HWND): Boolean;
  var
    WindowThreadID: Cardinal;
  begin
    WindowThreadID := GetWindowThreadProcessId(Window, nil);
    EnumFoundWindow := 0;
    EnumThreadWindows(WindowThreadID, @EnumNotifyWinProc, 0);
    ParentWindow := EnumFoundWindow;
    Result := (ParentWindow > 0) {and (ParentWindow <> Window)};
  end;

begin
  LogForm.Caption := 'Domina-Modus aktiv';
  LogForm.LogMemo.Lines.Clear;

  FVisible := True;
  UpdateWindowWorkarea;

  if Assigned(FLastUsedLayer) then
    EnterLayer(FLastUsedLayer)
  else
    EnterLayer(FLayers.First);
  DominaModeChanged;

  StartTargetWindowListener;
end;

procedure TMainForm.WD_ExitDominaMode(var Message: TMessage);
begin
  StopTargetWindowListener;

  LogForm.Caption := 'Normaler Modus';
  WDMKeyStates.ReleaseAllKeys;
  FLastUsedLayer := GetActiveLayer;
  ExitLayer;
  FActiveLayers.Clear;
  ClearWindowContent;
  ShowWindow(Handle, SW_HIDE);
  FVisible := False;
  DominaModeChanged;

  WindowPositioner.PushChangedWindowsPositions;
end;

procedure TMainForm.DominaModeChanged;
var
  Activated: Boolean;
begin
  Activated := IsDominaModeActivated;
  TrayIcon.IconIndex := IfThen(Activated, 1, 0);

  TrayIcon.Hint := Lang[0] + sLineBreak + // WinDomina
    IfThen(Activated, Lang[5] {Dominate-Modus ist aktiv}, Lang[6] {Dominate-Modus ist nicht aktiv}) + sLineBreak +
    Lang[7]; // Tippen Sie doppelt auf die CapsLock-Taste...

  ToggleDominaModeAction.Caption := IfThen(Activated, {End dominate mode} Lang[3], {Start dominate mode} Lang[2]);
end;

procedure TMainForm.WD_KeyDownDominaMode(var Message: TMessage);
var
  Handled: Boolean;
  Key: Integer;
  Layer, CurActiveLayer: TBaseLayer;
  Monitor: TMonitor;

  procedure PopPrevKnownWindowPosition;
  var
    CurWindow: TWindow;
  begin
    if not GetWindowList(wldDominaTargets).HasFirst(CurWindow) then
      Exit;

    WindowPositioner.EnterWindow(CurWindow.Handle);
    try
      WindowPositioner.PopWindowPosition;

      // Durch die Widerherstellung der Fensterposition kann sich der Zielmonitor verändert haben,
      // Dies sichern wir durch einen verzögernden Aufruf von UpdateWindowWorkarea
      UpdateWindowWorkareaDelayed(500);
    finally
      WindowPositioner.ExitWindow;
    end;
  end;

begin
  Key := Message.WParam;
  WDMKeyStates.KeyPressed[Key] := True;

  Handled := False;

  CurActiveLayer := GetActiveLayer;
  CurActiveLayer.HandleKeyDown(Key, Handled);

  if not Handled and LayerActivationKeys.TryGetValue(Key, Layer) and (Layer <> CurActiveLayer) then
  begin
    EnterLayer(Layer);
    Layer.HandleKeyDown(Key, Handled);
  end;

  if not Handled then
  begin
    case Key of
      vkTab:
        if HasNextMonitor(Monitor) then
          SetCurrentMonitor(Monitor);
      vkEscape:
        ExitDominaMode;
      vkF12:
      begin
        LogForm.Visible := not LogForm.Visible;
        if LogForm.Visible then
          SetWindowPos(LogForm.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
      end;
      vkBack:
        PopPrevKnownWindowPosition;
    end;
  end;
end;

procedure TMainForm.WD_KeyUpDominaMode(var Message: TMessage);
var
  Key: Integer;
  Handled: Boolean;
begin
  Key := Message.WParam;
  WDMKeyStates.KeyPressed[Key] := False;

  GetActiveLayer.HandleKeyUp(Key, Handled);
end;

{ TUpdateWindowThread }

constructor TUpdateWindowThread.Create;
begin
  UpdateWindowEvent := TEvent.Create(nil, False, False, '');

  inherited Create(False);
end;

procedure TUpdateWindowThread.Execute;

  procedure UpdateWindow;
  var
    Info: TUpdateLayeredWindowInfo;
    SourcePosition: TPoint;
    WindowPosition: TPoint;
    Blend: TBlendFunction;
    Size: TSize;
  begin
    SourcePosition := GR32.Point(0, 0);
    WindowPosition := GR32.Point(0, 0);
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := 255;
    Blend.AlphaFormat := AC_SRC_ALPHA;

    Bitmap.Lock;
    try
      Size.cx := Bitmap.Width;
      Size.cy := Bitmap.Height;
      if Bitmap.Empty then
        Exit;

      ZeroMemory(@Info, SizeOf(Info));
      Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
      Info.pptSrc := @SourcePosition;
      Info.pptDst := @WindowPosition;
      Info.psize  := @Size;
      Info.pblend := @Blend;
      Info.dwFlags := ULW_ALPHA;
      Info.hdcSrc := Bitmap.Handle;

      if not UpdateLayeredWindowIndirect(WindowHandle, @Info) then
        RaiseLastOSError();

      Bitmap.Clear(Color32(0, 0, 0, 0));
      ContentValid := False;
    finally
      Bitmap.Unlock;
    end;
  end;

begin
  while not Terminated do
    if (UpdateWindowEvent.WaitFor = wrSignaled) and ContentValid and not Terminated then
      UpdateWindow;
end;

// Sagt dem Thread, dass er das Fenster aktualisieren soll
//
// Da an dieser Stelle keine eigenen Locks implementiert sind, darf diese Methode nur
// aufgerufen werden, während die Bitmap gelockt ist.
procedure TUpdateWindowThread.RequestUpdateWindow;
begin
  ContentValid := True;
  UpdateWindowEvent.SetEvent;
end;

procedure TUpdateWindowThread.TerminatedSet;
begin
  UpdateWindowEvent.SetEvent;
end;

end.
