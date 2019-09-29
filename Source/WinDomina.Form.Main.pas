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
  Winapi.Windows,
  Winapi.Messages,
  Winapi.D2D1,
  Winapi.Wincodec,
  Winapi.DxgiFormat,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.Direct2D,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.Menus,
  Vcl.ActnList,

  AnyiQuack,
  Localization,
  SendInputHelper,
  WindowEnumerator,

  WinDomina.Types,
  WinDomina.WindowTools,
  WinDomina.WindowPositioner,
  WinDomina.Registry,
  WinDomina.Layer,
  WinDomina.KBHKLib,
  WinDomina.Form.Log,
  WinDomina.Types.Drawing;

type
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
    TargetWindowListenerIntervalID: Integer;

    var
    FVisible: Boolean;
    FLayers: TLayerList;
    FActiveLayers: TLayerList;
    FLastUsedLayer: TBaseLayer;
    FWindowList: TDomainWindowList;

    FDrawContext: IDrawContext;
    FWICBitmap: IWICBitmap;
    FInteropRenderTarget: ID2D1GdiInteropRenderTarget;

    FBlend: TBlendFunction;
    FSourcePosition: TPoint;
    FWindowPosition: TPoint;
    FWindowSize: TSize;
    FDeviceResourcesValid: Boolean;

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
    procedure UpdateWindow(SourceDC: HDC);
    procedure RenderWindowContent;
    procedure CreateDeviceResources;
    procedure InvalidateDeviceResources;

  private
    FPrevTargetWindow: TWindow;

    procedure StartTargetWindowListener;
    procedure CheckTargetWindow;
    procedure StopTargetWindowListener;
    procedure DoTargetWindowChanged;
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

var
  MainForm: TMainForm;

implementation

uses
  WinDomina.Layer.Grid,
  WinDomina.Layer.Mover;

{$R *.dfm}

type
  TDrawContext = class(TInterfacedObject, IDrawContext)
  private
    FD2DFactory: ID2D1Factory;
    FWICFactory: IWICImagingFactory;
    FDirectWriteFactory: IDWriteFactory;
    FRenderTarget: ID2D1RenderTarget;

  protected
    function D2DFactory: ID2D1Factory;
    function WICFactory: IWICImagingFactory;
    function DirectWriteFactory: IDWriteFactory;
    function RenderTarget: ID2D1RenderTarget;
  end;

{ TDrawContext }

function TDrawContext.D2DFactory: ID2D1Factory;
begin
  Result := FD2DFactory;
end;

function TDrawContext.WICFactory: IWICImagingFactory;
begin
  Result := FWICFactory;
end;

function TDrawContext.DirectWriteFactory: IDWriteFactory;
begin
  Result := FDirectWriteFactory;
end;

function TDrawContext.RenderTarget: ID2D1RenderTarget;
begin
  Result := FRenderTarget;
end;

{ TMainForm }

class constructor TMainForm.Create;
begin
  UpdateWindowWorkareaDelayID := TAQ.GetUniqueID;
  TargetWindowListenerIntervalID := TAQ.GetUniqueID;
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

  function CreateDrawContext: IDrawContext;
  var
    DC: TDrawContext;
  begin
    DC := TDrawContext.Create;
    DC.FD2DFactory := Vcl.Direct2D.D2DFactory;
    DC.FWICFactory := CreateComObject(CLSID_WICImagingFactory) as IWICImagingFactory;
    DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, IDWriteFactory, IInterface(DC.FDirectWriteFactory));

    Result := DC;
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
  // Diese Prüfung ist eigentlich nicht notwendig und ist mehr ein Workaround, damit der
  // Klassenkonstruktor von TDirect2DCanvas ausgeführt wird. Sonst gibt es eine AV, zumindest in
  // Delphi 10.3.
  if not TDirect2DCanvas.Supported then
    raise Exception.Create('TDirect2DCanvas not supported');

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

  FDrawContext := CreateDrawContext;
  FBlend.BlendOp := AC_SRC_OVER;
  FBlend.BlendFlags := 0;
  FBlend.SourceConstantAlpha := 255;
  FBlend.AlphaFormat := AC_SRC_ALPHA;

  FSourcePosition := Point(0, 0);
  FWindowPosition := Point(0, 0);
  FWindowSize.cx := Width;
  FWindowSize.cy := Height;

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
  FWindowPosition := Workarea.Location;
  FWindowSize.cx := Workarea.Width;
  FWindowSize.cy := Workarea.Height;

  FVisible := True;
  SetWindowPos(Handle, HWND_TOPMOST, Workarea.Left, Workarea.Top, Workarea.Width, Workarea.Height,
    SWP_SHOWWINDOW or SWP_NOACTIVATE {or SWP_NOSIZE or SWP_NOMOVE});
  UpdateBoundsRect(Workarea);

  InvalidateDeviceResources;
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
  ActivateFromPoint: TPoint;
begin
  if GetWindowList(wldDominaTargets).HasFirst(TargetWindow) then
    ActivateFromPoint := TargetWindow.Rect.Location
  else
    ActivateFromPoint := Mouse.CursorPos;

  AdjustWindowWorkareaFromPoint(ActivateFromPoint);
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
    DoTargetWindowChanged
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

procedure TMainForm.DoTargetWindowChanged;
begin
  UpdateWindowWorkareaDelayed(500);
  GetActiveLayer.TargetWindowChanged;
end;

procedure TMainForm.DoTargetWindowMoved;
begin
  UpdateWindowWorkareaDelayed(500);
  GetActiveLayer.TargetWindowMoved;
end;

procedure TMainForm.UpdateWindow(SourceDC: HDC);
var
  Info: TUpdateLayeredWindowInfo;
begin
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
  Info.pptSrc := @FSourcePosition;
  Info.pptDst := @FWindowPosition;
  Info.psize  := @FWindowSize;
  Info.pblend := @FBlend;
  Info.dwFlags := ULW_ALPHA;
  Info.hdcSrc := SourceDC;

  if not UpdateLayeredWindowIndirect(Handle, @Info) then
    RaiseLastOSError();
end;

procedure TMainForm.RenderWindowContent;
{.$DEFINE BOTTLENECK_LOG}
var
  RT: ID2D1RenderTarget;
  DC: HDC;
  Layer: TBaseLayer;
  LayerParams: TD2D1LayerParameters;
  D2DLayer: ID2D1Layer;
  D2DLayerDrawing: Boolean;
{$IFDEF BOTTLENECK_LOG}
  WholeStopper, BottleneckStopper: TStopwatch;
{$ENDIF}
  EndDrawResult: HRESULT;
begin
{$IFDEF BOTTLENECK_LOG}
  WholeStopper := TStopwatch.StartNew;
  BottleneckStopper := TStopwatch.StartNew;
{$ENDIF}
  CreateDeviceResources;
{$IFDEF BOTTLENECK_LOG}
  BottleneckStopper.Stop;
  Logging.AddLog('Dauer CreateDeviceResources ' + BottleneckStopper.ElapsedMilliseconds.ToString + ' msec.');
{$ENDIF}

  RT := FDrawContext.RenderTarget;

  RT.BeginDraw;
  try
    RT.Clear(D2D1ColorF(clBlack, 0));

    if HasActiveLayer(Layer) and
      Layer.HasMainContent(FDrawContext, LayerParams, D2DLayer) then
    begin
{$IFDEF BOTTLENECK_LOG}
      BottleneckStopper := TStopwatch.StartNew;
{$ENDIF}
      D2DLayerDrawing := Assigned(D2DLayer);

      if D2DLayerDrawing then
        RT.PushLayer(LayerParams, D2DLayer);
      try
        Layer.RenderMainContent(FDrawContext, LayerParams);
      finally
        if D2DLayerDrawing then
          RT.PopLayer;
      end;

{$IFDEF BOTTLENECK_LOG}
      BottleneckStopper.Stop;
      Logging.AddLog('Dauer RenderMainContent ' + BottleneckStopper.ElapsedMilliseconds.ToString + ' msec.');
{$ENDIF}
    end;
{$IFDEF BOTTLENECK_LOG}
    BottleneckStopper := TStopwatch.StartNew;
{$ENDIF}

    FInteropRenderTarget.GetDC(D2D1_DC_INITIALIZE_MODE_COPY, DC);
    try
      UpdateWindow(DC);
    finally
      FInteropRenderTarget.ReleaseDC(TRect.Empty);
    end;
{$IFDEF BOTTLENECK_LOG}
    BottleneckStopper.Stop;
    Logging.AddLog('Dauer UpdateWindow ' + BottleneckStopper.ElapsedMilliseconds.ToString + ' msec.');
{$ENDIF}
  finally
    EndDrawResult := RT.EndDraw;
  end;

  if EndDrawResult = D2DERR_RECREATE_TARGET then
    InvalidateDeviceResources;
{$IFDEF BOTTLENECK_LOG}
  WholeStopper.Stop;
  Logging.AddLog('Dauer kompletter RenderWindowContent ' + WholeStopper.ElapsedMilliseconds.ToString + ' msec.');
  Logging.AddLog('---');
{$ENDIF}
end;

procedure TMainForm.CloseActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.CreateDeviceResources;
var
  PF: TD2D1PixelFormat;
  RTP: TD2D1RenderTargetProperties;
  RenderTarget: ID2D1RenderTarget;
  DrawContextObject: TDrawContext;
begin
  if FDeviceResourcesValid then
    Exit;

  FDrawContext.WICFactory.CreateBitmap(Width, Height, @GUID_WICPixelFormat32bppPBGRA,
    WICBitmapCacheOnLoad, FWICBitmap);

  PF.format := DXGI_FORMAT_B8G8R8A8_UNORM;
  PF.alphaMode := D2D1_ALPHA_MODE_PREMULTIPLIED;

  RTP := D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_DEFAULT, PF, 0, 0,
    D2D1_RENDER_TARGET_USAGE_GDI_COMPATIBLE);

  D2DFactory.CreateWicBitmapRenderTarget(FWICBitmap, RTP, RenderTarget);
  FInteropRenderTarget := RenderTarget as ID2D1GdiInteropRenderTarget;

  DrawContextObject := TDrawContext(FDrawContext);
  if DrawContextObject is TDrawContext then
    DrawContextObject.FRenderTarget := RenderTarget;

  FDeviceResourcesValid := True;
end;

procedure TMainForm.InvalidateDeviceResources;
var
  Layer: TBaseLayer;
begin
  if not FDeviceResourcesValid then
    Exit;

  FDeviceResourcesValid := False;

  for Layer in FLayers do
    Layer.InvalidateMainContentResources;
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
    InvalidateDeviceResources;
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

end.
