unit WinDomina.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.Generics.Collections, Vcl.StdCtrls,
  WinDomina.Types, WinDomina.WindowTools, WinDomina.Registry, WinDomina.Layer,
  WinDomina.KBHKLib;

type
  TMainForm = class(TForm)
    LogMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    Layers: TLayerList;
    ActiveLayers: TLayerList;

    procedure AddLayer(Layer: TBaseLayer);
    function GetActiveLayer: TBaseLayer;
    procedure EnterLayer(Layer: TBaseLayer);
    procedure ExitLayer;

    procedure LogWindow(Window: THandle);

    procedure WD_EnterDominaMode(var Message: TMessage); message WD_ENTER_DOMINA_MODE;
    procedure WD_ExitDominaMode(var Message: TMessage); message WD_EXIT_DOMINA_MODE;
    procedure WD_KeyDownDominaMode(var Message: TMessage); message WD_KEYDOWN_DOMINA_MODE;
    procedure WD_KeyUpDominaMode(var Message: TMessage); message WD_KEYUP_DOMINA_MODE;
  end;

var
  MainForm: TMainForm;

implementation

uses
  WinDomina.Layer.Grid,
  WinDomina.Layer.Mover;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);

  procedure AddLayers;
  begin
    AddLayer(TGridLayer.Create);
    AddLayer(TMoverLayer.Create);
  end;

begin
  RegisterLogging(TStringsLogging.Create(LogMemo.Lines));
  Layers := TLayerList.Create(True);
  ActiveLayers := TLayerList.Create(False);
  RegisterWDMKeyStates(TKeyStates.Create);
  RegisterLayerActivationKeys(TKeyLayerList.Create);
  RegisterDominaWindows(TWindowList.Create);

  AddLayers;

  InstallHook(Handle);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ActiveLayers.Free;
  Layers.Free;

  UninstallHook;
end;

procedure TMainForm.AddLayer(Layer: TBaseLayer);
begin
  Layers.Add(Layer);
end;

function TMainForm.GetActiveLayer: TBaseLayer;
begin
  Result := ActiveLayers.First;
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
    Layer.EnterLayer;
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

var
  AppWins: TWindowList;
  AppWin: THandle;
begin
  Caption := 'Domina-Modus aktiv';
  LogMemo.Lines.Clear;

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

  EnterLayer(Layers.First);
end;

procedure TMainForm.WD_ExitDominaMode(var Message: TMessage);
begin
  Caption := 'Normaler Modus';
  WDMKeyStates.ReleaseAllKeys;
  ExitLayer;
  ActiveLayers.Clear;
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
      VK_ESCAPE:
        ExitDominaMode;
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
