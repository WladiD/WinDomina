// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.Form.Main;

interface

uses

  Winapi.Windows,
  Winapi.Messages,

  System.Actions,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.ImageList,
  System.IniFiles,
  System.Math,
  System.Skia,
  System.StrUtils,
  System.SyncObjs,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Variants,
  System.Win.ComObj,
  Vcl.ActnList,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ImgList,
  Vcl.Menus,
  Vcl.Skia,
  Vcl.StdCtrls,

  AnyiQuack,
  Localization,
  SendInputHelper,
  WindowEnumerator,

  WD.Form.Log,
  WD.KBHKLib,
  WD.KeyTools,
  WD.LangIndex,
  WD.Layer,
  WD.Registry,
  WD.Types,
  WD.Types.Messages,
  WD.Types.Actions,
  WD.WindowPositioner,
  WD.WindowTools;

type

  TMainForm = class(TForm, ITranslate, IMonitorHandler, IWindowsHandler)
    ActionList: TActionList;
    CloseAction: TAction;
    CloseMenuItem: TMenuItem;
    SettingsAction: TAction;
    SettingsMenuItem: TMenuItem;
    ToggleDominaModeAction: TAction;
    ToggleDominaModeMenuItem: TMenuItem;
    TrayIcon: TTrayIcon;
    TrayImageList: TImageList;
    TrayPopupMenu: TPopupMenu;
    procedure CloseActionExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SettingsActionExecute(Sender: TObject);
    procedure ToggleDominaModeActionExecute(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  private
    type
    TDomainWindowList = TObjectDictionary<TWindowListDomain, TWindowList>;

    class var
    PushChangedWindowsPositionsDelayID: Integer;
    TargetWindowChangedDelayID        : Integer;
    TargetWindowMovedDelayID          : Integer;
    UpdateWindowWorkareaDelayID       : Integer;
    WindowsTrackingIntervalID         : Integer;

    var
    FActiveLayers                : TLayerList;
    FBitmapBits                  : Pointer;
    FBitmapHeight                : Integer;
    FBitmapWidth                 : Integer;
    FCapsLockAction              : TCapsLockAction;
    FDIBBitmap                   : HBITMAP;
    FDisableLayerExitEventHandler: Boolean;
    FLastUsedLayer               : TBaseLayer;
    FLayers                      : TLayerList;
    FLeftWinAction               : TLeftWinAction;
    FMemoryDC                    : HDC;
    FOldBitmap                   : HBITMAP;
    FRightCtrlAction             : TRightCtrlAction;
    FSkSurface                   : ISkSurface;
    FVisible                     : Boolean;
    FWindowList                  : TDomainWindowList;

    procedure LoadConfig;
    procedure SaveConfig;
    procedure AddLayer(Layer: TBaseLayer);
    function  GetActiveLayer: TBaseLayer;
    function  GetPrevOrDefaultLayer: TBaseLayer;
    procedure EnterLayer(Layer: TBaseLayer);
    procedure ExitLayer;
    procedure LayerMainContentChangedEventHandler(Sender: TObject);
    procedure LayerExitEventHandler(Sender: TObject);
    procedure LogWindow(Window: THandle);

    procedure WD_EnterDominaMode(var Message: TMessage); message WD_ENTER_DOMINA_MODE;
    procedure WD_ExitDominaMode(var Message: TMessage); message WD_EXIT_DOMINA_MODE;
    procedure WD_KeyDownDominaMode(var Message: TMessage); message WD_KEYDOWN_DOMINA_MODE;
    procedure WD_KeyUpDominaMode(var Message: TMessage); message WD_KEYUP_DOMINA_MODE;
    procedure DominaModeChanged;

    procedure WMMouseActivate(var Message: TWMMouseActivate); message WM_MOUSEACTIVATE;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;

    procedure UpdateWindowWorkarea(ForceMode: Boolean = False; NewWorkarea: PRect = nil);
    procedure UpdateWindowWorkareaDelayed(Delay: Integer);
    procedure EnsureDIB(AWidth, AHeight: Integer);
    procedure RenderWindowContent;
    procedure ClearWindowContent;

  private
    FPrevTargetWindow: TWindow;

    procedure StartWindowsTracking;
    procedure CheckWindowsTracking;
    procedure StopWindowsTracking;
    procedure DoTargetWindowChanged(PrevTargetWindowHandle, NewTargetWindowHandle: HWND);
    procedure DoTargetWindowMoved;

  // ITranslate-Interface
  private
    function  IsReadyForTranslate: Boolean;
    procedure OnReadyForTranslate(NotifyEvent: TNotifyEvent);
    procedure Translate;

  // IMonitorHandler-Interface
  private
    function  HasAdjacentMonitor(Direction: TDirection; out AdjacentMonitor: TMonitor): Boolean;
    function  HasNextMonitor(out Monitor: TMonitor): Boolean;
    function  HasPrevMonitor(out Monitor: TMonitor): Boolean;

    function  ClientToScreen(const Rect: TRect): TRect; overload;
    function  ScreenToClient(const Rect: TRect): TRect; overload;

    function  ConvertMmToPixel(MM: Real): Integer;

    function  ScaleFactor: Single;

    function  GetCurrentMonitor: TMonitor;
    procedure SetCurrentMonitor(Monitor: TMonitor);

  // IWindowsHandler-Interface
  private
    function  CreateWindowList(Domain: TWindowListDomain): TWindowList;
    procedure UpdateWindowList(Domain: TWindowListDomain);
    function  GetWindowList(Domain: TWindowListDomain): TWindowList;

  public
    class constructor Create;
  end;

var
  MainForm: TMainForm;

implementation

uses

  WD.Layer.Grid,
  WD.Layer.Mover,
  WD.Layer.KeyViewer,
  WD.Form.Settings;

{$R *.dfm}

{ TMainForm }

class constructor TMainForm.Create;
begin
  UpdateWindowWorkareaDelayID := TAQ.GetUniqueID;
  WindowsTrackingIntervalID := TAQ.GetUniqueID;
  PushChangedWindowsPositionsDelayID := TAQ.GetUniqueID;
  TargetWindowChangedDelayID := TAQ.GetUniqueID;
  TargetWindowMovedDelayID := TAQ.GetUniqueID;
end;

procedure TMainForm.LoadConfig;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(RuntimeInfo.DefaultPath + 'Config.ini');
  try
    FCapsLockAction := TCapsLockAction(Ini.ReadInteger('Settings', 'CapsLockAction', Ord(claActivateWD)));
    FLeftWinAction := TLeftWinAction(Ini.ReadInteger('Settings', 'LeftWinAction', Ord(lwaActivateWD)));
    FRightCtrlAction := TRightCtrlAction(Ini.ReadInteger('Settings', 'RightCtrlAction', Ord(rcaDoNothing)));

    WD.KBHKLib.SetCapsLockAction(FCapsLockAction);
    WD.KBHKLib.SetLeftWinAction(FLeftWinAction);
    WD.KBHKLib.SetRightCtrlAction(FRightCtrlAction);
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.SaveConfig;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(RuntimeInfo.DefaultPath + 'Config.ini');
  try
    Ini.WriteInteger('Settings', 'CapsLockAction', Ord(FCapsLockAction));
    Ini.WriteInteger('Settings', 'LeftWinAction', Ord(FLeftWinAction));
    Ini.WriteInteger('Settings', 'RightCtrlAction', Ord(FRightCtrlAction));

    WD.KBHKLib.SetCapsLockAction(FCapsLockAction);
    WD.KBHKLib.SetLeftWinAction(FLeftWinAction);
    WD.KBHKLib.SetRightCtrlAction(FRightCtrlAction);
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);

  function CreateLayer(LayerClass: TBaseLayerClass): TBaseLayer;
  begin
    Result := LayerClass.Create(Self);
    Result.MonitorHandler := Self;
    Result.WindowsHandler := Self;
    Result.OnMainContentChanged := LayerMainContentChangedEventHandler;
    Result.OnExitLayer := LayerExitEventHandler;
    Result.OnGetPrevLayer := GetPrevOrDefaultLayer;
  end;

  procedure AddLayers;
  begin
    AddLayer(CreateLayer(TMoverLayer));
    AddLayer(CreateLayer(TGridLayer));
    AddLayer(CreateLayer(TKeyViewerLayer));
  end;

  function CreateWindowPositioner: TWindowPositioner;
  begin
    Result := TWindowPositioner.Create;
    Result.WindowsHandler := Self;
  end;

  function CreateKeyRenderManager: TKeyRenderManager;
  begin
    Result := TKeyRenderManager.Create(Self);
  end;

var
  Logger: TStringsLogging;
begin
  BorderStyle := bsNone;
  SetWindowLong(Handle, GWL_EXSTYLE, GetWindowLong(Handle, GWL_EXSTYLE) or WS_EX_LAYERED);

  LogForm := TLogForm.Create(Self);
  Logger := TStringsLogging.Create(LogForm.LogMemo.Lines);
  Logger.WindowHandle := LogForm.Handle;
  RegisterLogging(Logger);

  FWindowList := TDomainWindowList.Create([doOwnsValues]);
  FLayers := TLayerList.Create(True);
  FActiveLayers := TLayerList.Create(False);
  FPrevTargetWindow := TWindow.Create;
  RegisterWDMKeyStates(TKeyStates.Create);
  RegisterLayerActivationKeys(TKeyLayerList.Create);
  RegisterWindowPositioner(CreateWindowPositioner);
  RegisterKeyRenderManager(CreateKeyRenderManager);

  AddLayers;

  // Initialisierung der RuntimeInfo
  RuntimeInfo.DefaultPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  RuntimeInfo.CommonPath := IncludeTrailingPathDelimiter(RuntimeInfo.DefaultPath + 'common');

  InitializeLang(RuntimeInfo.CommonPath);

  LoadConfig;

  InstallHook(Handle);

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

  if FDIBBitmap <> 0 then
  begin
    SelectObject(FMemoryDC, FOldBitmap);
    DeleteObject(FDIBBitmap);
  end;
  if FMemoryDC <> 0 then
    DeleteDC(FMemoryDC);

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
  TrayIcon.BalloonTitle := Lang[LS_2];
  TrayIcon.BalloonHint := Lang[LS_4];

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
  cc             : Integer;
  CurBounds      : TRect;
  CurMonitorIndex: Integer;
  TestMonitor    : TMonitor;
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

function TMainForm.ConvertMmToPixel(MM: Real): Integer;
begin
  Result := Round(Monitor.PixelsPerInch / 25.4 {MM per Inch} * MM);
end;

function TMainForm.ScaleFactor: Single;
begin
  Result := Monitor.PixelsPerInch / 96;
end;

function TMainForm.GetCurrentMonitor: TMonitor;
begin
  Result := Monitor;
end;

procedure TMainForm.SetCurrentMonitor(Monitor: TMonitor);
var
  Rect: TRect;
begin
  Rect := Monitor.WorkareaRect;
  UpdateWindowWorkarea(False, @Rect);
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
        Result.OverlappedWindowsFilter := False;
        Result.InactiveTopMostWindowsFilter := True;
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

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST or WS_EX_NOACTIVATE;
end;

procedure TMainForm.WMMouseActivate(var Message: TWMMouseActivate);
begin
  Message.Result := MA_NOACTIVATE;
end;

// Aktualisiert die Position dieses Forms auf die Arbeitsfläche des Monitors auf dem sich das
// aktuelle Fenster befindet. Wenn kein Zielfenster vorhanden ist, so wird die Position des
// Mauscursors verwendet.
procedure TMainForm.UpdateWindowWorkarea(ForceMode: Boolean; NewWorkarea: PRect);

  // Passt das Fenster an die übergebene Arbeitsfläche an und setzt es in den Vordergrund
  procedure AdjustWindowWorkarea(Workarea: TRect);
  begin
    if not ((FVisible and (BoundsRect <> Workarea)) or ForceMode) then
      Exit;

    FVisible := True;

    // Ensure VCL knows the new bounds
    SetBounds(Workarea.Left, Workarea.Top, Workarea.Width, Workarea.Height);

    // Force TopMost and Show - this is the way master did it
    SetWindowPos(Handle, HWND_TOPMOST, Workarea.Left, Workarea.Top, Workarea.Width, Workarea.Height,
      SWP_SHOWWINDOW or SWP_NOACTIVATE);

    GetActiveLayer.Invalidate;
    RenderWindowContent;
  end;

  procedure AdjustWindowWorkareaFromMonitor(Monitor: TMonitor);
  begin
    if Assigned(Monitor) then
      AdjustWindowWorkarea(Monitor.WorkareaRect);
  end;

  procedure AdjustWindowWorkareaFromPoint(Point: TPoint);
  begin
    AdjustWindowWorkareaFromMonitor(Screen.MonitorFromPoint(Point));
  end;

var
  TargetWindow: TWindow;
begin
  if Assigned(NewWorkarea) then
    AdjustWindowWorkarea(NewWorkarea^)
  else if GetWindowList(wldDominaTargets).HasFirst(TargetWindow) then
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

procedure TMainForm.StartWindowsTracking;
begin
  Take(Self)
    .CancelIntervals(WindowsTrackingIntervalID)
    .EachInterval(100,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        CheckWindowsTracking;
        Result := False;
      end, WindowsTrackingIntervalID);
end;

procedure TMainForm.CheckWindowsTracking;
var
  TargetWindow: TWindow;
begin
  // Diese Methode wird überwiegend aus einer verzögernden Methode aufgerufen. In bestimmten Fällen
  // kann sie auch noch aufgerufen werden, wenn der Domina-Modus nicht mehr aktiv ist. Dann kann es
  // hier zu Zugriffsverletzungen kommen. Dies soll diese Weiche verhindern.
  if not IsDominaModeActivated then
    Exit;

  UpdateWindowList(wldDominaTargets);
  if not GetWindowList(wldDominaTargets).HasFirst(TargetWindow) then
    Exit;

  if TargetWindow.Handle <> FPrevTargetWindow.Handle then
    DoTargetWindowChanged(FPrevTargetWindow.Handle, TargetWindow.Handle)
  else if TargetWindow.Rect <> FPrevTargetWindow.Rect then
    DoTargetWindowMoved;

  FPrevTargetWindow.Assign(TargetWindow);
end;

procedure TMainForm.StopWindowsTracking;
begin
  Take(Self)
    .CancelIntervals(WindowsTrackingIntervalID);
  FPrevTargetWindow.Handle := 0;
  FPrevTargetWindow.Rect := TRect.Empty;
end;

// Sollte aufgerufen werden, wenn sich das Zielfenster verändert
procedure TMainForm.DoTargetWindowChanged(PrevTargetWindowHandle, NewTargetWindowHandle: HWND);

  procedure NotifyTargetWindowChanged(Layer: TBaseLayer);
  var
    Delay: Integer;
  begin
    Delay := Layer.GetTargetWindowChangedDelay;

    if Delay = 0 then
    begin
      UpdateWindowWorkarea(True);
      Layer.TargetWindowChanged;
    end
    else if Delay > 0 then
    begin
      UpdateWindowWorkareaDelayed(Delay);
      Take(Layer)
        .CancelDelays(TargetWindowChangedDelayID)
        .EachDelay(Delay,
          function(AQ: TAQ; O: TObject): Boolean
          begin
            if GetActiveLayer = Layer then
              Layer.TargetWindowChanged;
            Result := True;
          end, TargetWindowChangedDelayID);
    end;
  end;

begin
  if wtTargetChanged in GetActiveLayer.GetRequiredWindowTrackings then
    NotifyTargetWindowChanged(GetActiveLayer);

  // Damit die Position des Zielfensters im Positioner erfasst wird
  WindowPositioner.EnterWindow(NewTargetWindowHandle);
  WindowPositioner.ExitWindow;
end;

// Sollte aufgerufen werden, wenn sich die Position des Zielfensters ändert
procedure TMainForm.DoTargetWindowMoved;

  procedure NotifyTargetWindowMoved(Layer: TBaseLayer);
  var
    Delay: Integer;
  begin
    Delay := Layer.GetTargetWindowMovedDelay;

    if Delay = 0 then
    begin
      UpdateWindowWorkarea;
      Layer.TargetWindowMoved;
    end
    else if Delay > 0 then
    begin
      UpdateWindowWorkareaDelayed(Delay);
      Take(Layer)
        .CancelDelays(TargetWindowMovedDelayID)
        .EachDelay(Delay,
          function(AQ: TAQ; O: TObject): Boolean
          begin
            if GetActiveLayer = Layer then
              Layer.TargetWindowMoved;
            Result := True;
          end, TargetWindowMovedDelayID);
    end;
  end;

begin
  if wtTargetMoved in GetActiveLayer.GetRequiredWindowTrackings then
    NotifyTargetWindowMoved(GetActiveLayer);

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

procedure TMainForm.EnsureDIB(AWidth, AHeight: Integer);
var
  BI: TBitmapInfo;
begin
  if (AWidth = FBitmapWidth) and (AHeight = FBitmapHeight) and (FDIBBitmap <> 0) then
    Exit;

  if FDIBBitmap <> 0 then
  begin
    SelectObject(FMemoryDC, FOldBitmap);
    DeleteObject(FDIBBitmap);
    FDIBBitmap := 0;
    FSkSurface := nil;
  end;

  if FMemoryDC = 0 then
    FMemoryDC := CreateCompatibleDC(0);

  FBitmapWidth := 0;
  FBitmapHeight := 0;
  FBitmapBits := nil;

  if (AWidth > 0) and (AHeight > 0) then
  begin
    FillChar(BI, SizeOf(BI), 0);
    BI.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BI.bmiHeader.biWidth := AWidth;
    BI.bmiHeader.biHeight := -AHeight; // Top-Down
    BI.bmiHeader.biPlanes := 1;
    BI.bmiHeader.biBitCount := 32;
    BI.bmiHeader.biCompression := BI_RGB;

    FDIBBitmap := CreateDIBSection(FMemoryDC, BI, DIB_RGB_COLORS, FBitmapBits, 0, 0);
    if FDIBBitmap <> 0 then
    begin
      FOldBitmap := SelectObject(FMemoryDC, FDIBBitmap);
      FBitmapWidth := AWidth;
      FBitmapHeight := AHeight;

      FSkSurface := TSkSurface.MakeRasterDirect(
        TSkImageInfo.Create(AWidth, AHeight, TSkColorType.BGRA8888, TSkAlphaType.Premul),
        FBitmapBits, AWidth * 4);
    end;
  end;
end;

procedure TMainForm.RenderWindowContent;
var
  Blend         : TBlendFunction;
  Info          : TUpdateLayeredWindowInfo;
  Size          : TSize;
  SourcePosition: TPoint;
  WindowPosition: TPoint;
  Layer         : TBaseLayer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;

  EnsureDIB(Width, Height);
  if not Assigned(FSkSurface) then
    Exit;

  FSkSurface.Canvas.Clear(TAlphaColors.Null);

  for Layer in FActiveLayers do
    if Layer.HasMainContent then
    begin
      Layer.RenderMainContentSkia(FSkSurface.Canvas);
      if Layer.Exclusive then
        Break;
    end;

  SourcePosition := Point(0, 0);
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 255;
  Blend.AlphaFormat := AC_SRC_ALPHA;

  ZeroMemory(@Info, SizeOf(Info));
  WindowPosition := BoundsRect.Location;
  Size.cx := Width;
  Size.cy := Height;

  Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
  Info.pptSrc := @SourcePosition;
  Info.pptDst := @WindowPosition;
  Info.psize  := @Size;
  Info.pblend := @Blend;
  Info.dwFlags := ULW_ALPHA;
  Info.hdcSrc := FMemoryDC;

  if not UpdateLayeredWindowIndirect(Handle, @Info) then
    RaiseLastOSError();
end;

// Leert das Bitmap für das Layer-Window
//
// Wird beim Exit des Domina-Modus aufgerufen, weil sonst beim nächsten Start des Domina-Modus
// für einen kurzen Moment der vorherige Inhalt sichtbar sein kann.
procedure TMainForm.ClearWindowContent;
var
  Info: TUpdateLayeredWindowInfo;
  SourcePosition: TPoint;
  Blend: TBlendFunction;
  Size: TSize;
  WindowPosition: TPoint;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;

  EnsureDIB(Width, Height);
  if Assigned(FSkSurface) then
    FSkSurface.Canvas.Clear(TAlphaColors.Null);

  SourcePosition := Point(0, 0);
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 0; // Fully transparent
  Blend.AlphaFormat := AC_SRC_ALPHA;

  ZeroMemory(@Info, SizeOf(Info));
  WindowPosition := BoundsRect.Location;
  Size.cx := Width;
  Size.cy := Height;

  Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
  Info.pptSrc := @SourcePosition;
  Info.pptDst := @WindowPosition;
  Info.psize  := @Size;
  Info.pblend := @Blend;
  Info.dwFlags := ULW_ALPHA;
  Info.hdcSrc := FMemoryDC;

  UpdateLayeredWindowIndirect(Handle, @Info);
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

procedure TMainForm.EnterLayer(Layer: TBaseLayer);
var
  LayerIndex: Integer;
  CurLayer: TBaseLayer;
begin
  if FActiveLayers.Count > 0 then
  begin
    CurLayer := GetActiveLayer;
    if CurLayer.IsLayerActive and (CurLayer <> Layer) and Layer.Exclusive then
      CurLayer.ExitLayer;
  end;

  LayerIndex := FActiveLayers.IndexOf(Layer);

  if LayerIndex > 0 then
    FActiveLayers.Exchange(LayerIndex, 0)
  else if LayerIndex = -1 then
    FActiveLayers.Insert(0, Layer);

  if not Layer.IsLayerActive then
    Layer.EnterLayer;

  Caption := Lang[LS_0] + ': ' + Layer.GetDisplayName;
  RenderWindowContent;
end;

procedure TMainForm.ExitLayer;
var
  CurLayer: TBaseLayer;
begin
  FDisableLayerExitEventHandler := True;
  try
    for CurLayer in FActiveLayers do
      if CurLayer.IsLayerActive then
        CurLayer.ExitLayer;
  finally
    FDisableLayerExitEventHandler := False;
  end;
end;

function TMainForm.GetPrevOrDefaultLayer: TBaseLayer;
begin
  if FActiveLayers.Count > 1 then
    Result := FActiveLayers[1]
  else if (FActiveLayers.Count = 1) and (FActiveLayers[0] <> FLayers.First) then
    Result := FLayers.First
  else
    Result := nil;
end;

// Event handler for TBaseLayer.OnExitLayer
procedure TMainForm.LayerExitEventHandler(Sender: TObject);
var
  SenderLayer: TBaseLayer absolute Sender;
begin
  if FDisableLayerExitEventHandler or (GetActiveLayer <> SenderLayer) then
    Exit;

  SenderLayer := GetPrevOrDefaultLayer;

  if Assigned(SenderLayer) then
    EnterLayer(SenderLayer);
end;

procedure TMainForm.LayerMainContentChangedEventHandler(Sender: TObject);
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
begin
  LogForm.Caption := 'Domina-Modus aktiv';
  LogForm.LogMemo.Lines.Clear;

  FVisible := True;

  if Assigned(FLastUsedLayer) then
    EnterLayer(FLastUsedLayer)
  else
    EnterLayer(FLayers.First);

  UpdateWindowWorkarea(True);
  DominaModeChanged;

  StartWindowsTracking;
end;

procedure TMainForm.WD_ExitDominaMode(var Message: TMessage);
var
  TargetWindow: TWindow;

  function GetFirstOrExclusiveLayer: TBaseLayer;
  var
    CurLayer: TBaseLayer;
  begin
    Result := nil;
    for CurLayer in FActiveLayers do
      if CurLayer.Exclusive then
        Exit(CurLayer)
      else if not Assigned(Result) then
        Result := CurLayer;
  end;

begin
  // Wenn wir den Fokus haben, so dürfen diesen auch selbst vergeben (Sicherheitsrichtlinie von Windows 10)
  if GetWindowList(wldDominaTargets).HasFirst(TargetWindow) and (GetForegroundWindow = Handle) then
    SetForegroundWindow(TargetWindow.Handle);

  StopWindowsTracking;

  LogForm.Caption := 'Normaler Modus';
  WDMKeyStates.ReleaseAllKeys;
  FLastUsedLayer := GetFirstOrExclusiveLayer;
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

  TrayIcon.Hint := Lang[LS_0] + sLineBreak +
    IfThen(Activated, Lang[LS_5], Lang[LS_6]) + sLineBreak +
    Lang[LS_7];

  ToggleDominaModeAction.Caption := IfThen(Activated, Lang[LS_3], Lang[LS_2]);
end;

procedure TMainForm.SettingsActionExecute(Sender: TObject);
var
  Form: TSettingsForm;
begin
  Form := TSettingsForm.Create(Self);
  try
    // Init values
    Form.ComboBoxCapsLock.ItemIndex := Ord(FCapsLockAction);
    Form.ComboBoxLeftWin.ItemIndex := Ord(FLeftWinAction);
    Form.ComboBoxRightCtrl.ItemIndex := Ord(FRightCtrlAction);

    if Form.ShowModal = mrOk then
    begin
      // Read values
      if Form.ComboBoxCapsLock.ItemIndex >= 0 then
        FCapsLockAction := TCapsLockAction(Form.ComboBoxCapsLock.ItemIndex);

      if Form.ComboBoxLeftWin.ItemIndex >= 0 then
        FLeftWinAction := TLeftWinAction(Form.ComboBoxLeftWin.ItemIndex);

      if Form.ComboBoxRightCtrl.ItemIndex >= 0 then
        FRightCtrlAction := TRightCtrlAction(Form.ComboBoxRightCtrl.ItemIndex);

      SaveConfig;
    end;
  finally
    Form.Free;
  end;
end;

procedure TMainForm.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TMainForm.WD_KeyDownDominaMode(var Message: TMessage);
var
  Handled: Boolean;
  Key: Integer;
  Layer, CurActiveLayer: TBaseLayer;

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
    Handled := True;
  end;

  if not Handled then
  begin
    case Key of
      vkEscape,
      vkReturn:
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

end.
