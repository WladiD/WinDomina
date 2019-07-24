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

  WinDomina.Types,
  WinDomina.WindowTools,
  WinDomina.Registry,
  WinDomina.Layer,
  WinDomina.KBHKLib,
  WinDomina.Form.Log,
  WinDomina.Types.Drawing;

type
  TMainForm = class(TForm)
    TrayIcon: TTrayIcon;
    TrayImageList: TImageList;
    TrayPopupMenu: TPopupMenu;
    ActionList: TActionList;
    CloseAction: TAction;
    CloseMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CloseActionExecute(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
  private
    Layers: TLayerList;
    ActiveLayers: TLayerList;
    DrawContext: IDrawContext;
    WICBitmap: IWICBitmap;
    InteropRenderTarget: ID2D1GdiInteropRenderTarget;

    Blend: TBlendFunction;
    SourcePosition: TPoint;
    WindowPosition: TPoint;
    WindowSize: TSize;
    DeviceResourcesValid: Boolean;

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

    procedure UpdateWindow(SourceDC: HDC);
    procedure RenderWindowContent;
    procedure CreateDeviceResources;
    procedure InvalidateDeviceResources;

  // ITranslate-Interface
  private
    function IsReadyForTranslate: Boolean;
    procedure OnReadyForTranslate(NotifyEvent: TNotifyEvent);
    procedure Translate;
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

procedure TMainForm.FormCreate(Sender: TObject);

  function CreateLayer(LayerClass: TBaseLayerClass): TBaseLayer;
  begin
    Result := LayerClass.Create;
    Result.OnMainContentChanged := LayerMainContentChanged;
  end;

  procedure AddLayers;
  begin
    AddLayer(CreateLayer(TGridLayer));
    AddLayer(CreateLayer(TMoverLayer));
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

var
  ExStyle: DWORD;
begin
  LogForm := TLogForm.Create(Self);
  RegisterLogging(TStringsLogging.Create(LogForm.LogMemo.Lines));

  ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
  if (ExStyle and WS_EX_LAYERED) = 0 then
    SetWindowLong(Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);

  Layers := TLayerList.Create(True);
  ActiveLayers := TLayerList.Create(False);
  RegisterWDMKeyStates(TKeyStates.Create);
  RegisterLayerActivationKeys(TKeyLayerList.Create);
  RegisterDominaWindows(TWindowList.Create);

  AddLayers;

  // Initialisierung der RuntimeInfo
  RuntimeInfo.DefaultPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  RuntimeInfo.CommonPath := IncludeTrailingPathDelimiter(RuntimeInfo.DefaultPath + 'common');

  InstallHook(Handle);

  DrawContext := CreateDrawContext;
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 255;
  Blend.AlphaFormat := AC_SRC_ALPHA;

  SourcePosition := Point(0, 0);
  WindowPosition := Point(0, 0);
  WindowSize.cx := Width;
  WindowSize.cy := Height;

  InitializeLang(RuntimeInfo.CommonPath);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ActiveLayers.Free;
  Layers.Free;

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
  TrayIcon.Hint := Lang[0]; // WinDomina
end;

procedure TMainForm.TrayIconDblClick(Sender: TObject);
begin
  ToggleDominaMode;
end;

procedure TMainForm.UpdateWindow(SourceDC: HDC);
var
  Info: TUpdateLayeredWindowInfo;
begin
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
  Info.pptSrc := @SourcePosition;
  Info.pptDst := @WindowPosition;
  Info.psize  := @WindowSize;
  Info.pblend := @Blend;
  Info.dwFlags := ULW_ALPHA;
  Info.hdcSrc := SourceDC;

  if not UpdateLayeredWindowIndirect(Handle, @Info) then
    RaiseLastOSError();
end;

procedure TMainForm.RenderWindowContent;
var
  RT: ID2D1RenderTarget;
  DC: HDC;
  Layer: TBaseLayer;
  LayerParams: TD2D1LayerParameters;
  D2DLayer: ID2D1Layer;
  D2DLayerDrawing: Boolean;
begin
  CreateDeviceResources;

  RT := DrawContext.RenderTarget;

  RT.BeginDraw;
  try
    RT.Clear(D2D1ColorF(clBlack, 0));

    if HasActiveLayer(Layer) and
      Layer.HasMainContent(DrawContext, LayerParams, D2DLayer) then
    begin
      D2DLayerDrawing := Assigned(D2DLayer);

      if D2DLayerDrawing then
        RT.PushLayer(LayerParams, D2DLayer);
      try
        Layer.RenderMainContent(DrawContext, LayerParams);
      finally
        if D2DLayerDrawing then
          RT.PopLayer;
      end;
    end;

    InteropRenderTarget.GetDC(D2D1_DC_INITIALIZE_MODE_COPY, DC);
    try
      UpdateWindow(DC);
    finally
      InteropRenderTarget.ReleaseDC(TRect.Empty);
    end;
  finally
    RT.EndDraw;
  end;
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
  if DeviceResourcesValid then
    Exit;

  DrawContext.WICFactory.CreateBitmap(Width, Height, @GUID_WICPixelFormat32bppPBGRA,
    WICBitmapCacheOnLoad, WICBitmap);

  PF.format := DXGI_FORMAT_B8G8R8A8_UNORM;
  PF.alphaMode := D2D1_ALPHA_MODE_PREMULTIPLIED;

  RTP := D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_DEFAULT, PF, 0, 0,
    D2D1_RENDER_TARGET_USAGE_GDI_COMPATIBLE);

  D2DFactory.CreateWicBitmapRenderTarget(WICBitmap, RTP, RenderTarget);
  InteropRenderTarget := RenderTarget as ID2D1GdiInteropRenderTarget;

  DrawContextObject := TDrawContext(DrawContext);
  if DrawContextObject is TDrawContext then
    DrawContextObject.FRenderTarget := RenderTarget;

  DeviceResourcesValid := True;
end;

procedure TMainForm.InvalidateDeviceResources;
var
  Layer: TBaseLayer;
begin
  if not DeviceResourcesValid then
    Exit;

  DeviceResourcesValid := False;

  for Layer in Layers do
    Layer.InvalidateMainContentResources;
end;

procedure TMainForm.AddLayer(Layer: TBaseLayer);
begin
  Layers.Add(Layer);
end;

function TMainForm.GetActiveLayer: TBaseLayer;
begin
  Result := ActiveLayers.First;
end;

function TMainForm.HasActiveLayer(out Layer: TBaseLayer): Boolean;
begin
  Result := ActiveLayers.Count > 0;
  if Result then
    Layer := ActiveLayers.First;
end;

procedure TMainForm.EnterLayer(Layer: TBaseLayer);
var
  LayerIndex: Integer;
  CurLayer: TBaseLayer;
begin
  if ActiveLayers.Count > 0 then
  begin
    CurLayer := GetActiveLayer;
    if CurLayer.IsLayerActive and (CurLayer <> Layer) then
      CurLayer.ExitLayer;
  end;

  LayerIndex := ActiveLayers.IndexOf(Layer);

  if LayerIndex > 0 then
    ActiveLayers.Exchange(LayerIndex, 0)
  else if LayerIndex = -1 then
    ActiveLayers.Insert(0, Layer);

  if not Layer.IsLayerActive then
  begin
    Layer.EnterLayer;
    RenderWindowContent;
  end;
end;

procedure TMainForm.ExitLayer;
var
  CurLayer: TBaseLayer;
begin
  if ActiveLayers.Count > 0 then
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

function EnumAppWindowsProc(Window: THandle; Target: Pointer): Boolean; stdcall;
var
  WindowsList: TWindowList absolute Target;
  WindowStyle: NativeInt;
  Rect: TRect;

  function HasStyle(CheckMask: FixedUInt): Boolean;
  begin
    Result := (WindowStyle and CheckMask) = CheckMask;
  end;

begin
  WindowStyle := GetWindowLong(Window, GWL_STYLE);
  if HasStyle(WS_VISIBLE) and HasStyle(WS_SIZEBOX) and (not HasStyle(WS_POPUP)) and
    GetWindowRect(Window, Rect) and not Rect.IsEmpty then
    WindowsList.Add(Window);

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

  function CreateAppWindowList: TWindowList;
  var
    WindowThreadID: Cardinal;
    FGWindow: THandle;
  begin
    Result := TWindowList.Create;
    try
      FGWindow := GetForegroundWindow;
      WindowThreadID := GetWindowThreadProcessId(FGWindow, nil);
      EnumFoundWindow := 0;
      EnumThreadWindows(WindowThreadID, @EnumAppWindowsProc, NativeInt(Result));
      if Result.Count = 0 then
        Result.Add(FGWindow);
    except
      Result.Free;
      raise;
    end;
  end;

  procedure AdjustWindow;
  var
    WorkRect: TRect;
  begin
    if DominaWindows.Count > 0 then
      WorkRect := GetWorkareaRect(DominaWindows[0])
    else
      WorkRect := Screen.MonitorFromPoint(Mouse.CursorPos).WorkareaRect;

    WindowSize.cx := WorkRect.Width;
    WindowSize.cy := WorkRect.Height;

    SetWindowPos(Handle, HWND_TOPMOST, WorkRect.Left, WorkRect.Top, WorkRect.Width, WorkRect.Height,
      SWP_SHOWWINDOW or SWP_NOACTIVATE);
  end;

var
  AppWins: TWindowList;
  AppWin: THandle;
begin
  LogForm.Caption := 'Domina-Modus aktiv';
  LogForm.LogMemo.Lines.Clear;

  AppWins := CreateAppWindowList;
  try
    for AppWin in AppWins do
    begin
      LogWindow(AppWin);
    end;

    DominaWindows.Clear;
    DominaWindows.AddRange(AppWins);
//    BroadcastDominaWindowsChangeNotify;
  finally
    AppWins.Free;
  end;

  AdjustWindow;

  EnterLayer(Layers.First);
  TrayIcon.IconIndex := 1;
end;

procedure TMainForm.WD_ExitDominaMode(var Message: TMessage);
begin
  LogForm.Caption := 'Normaler Modus';
  WDMKeyStates.ReleaseAllKeys;
  ExitLayer;
  ActiveLayers.Clear;
  ShowWindow(Handle, SW_HIDE);
  TrayIcon.IconIndex := 0;
end;

procedure TMainForm.WD_KeyDownDominaMode(var Message: TMessage);
var
  Handled: Boolean;
  Key: Integer;
  Layer, CurActiveLayer: TBaseLayer;
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
      vkEscape:
        ExitDominaMode;
      vkF12:
      begin
        LogForm.Visible := not LogForm.Visible;
        if LogForm.Visible then
          SetWindowPos(LogForm.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
      end;
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
