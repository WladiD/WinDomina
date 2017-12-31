unit WinDomina.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.Generics.Collections, Vcl.StdCtrls,
  WinDomina.Types, WinDomina.WindowTools, WinDomina.Registry;

type
  TInstallHook = function(Hwnd: THandle): Boolean; stdcall;
  TUninstallHook = function: Boolean; stdcall;

  TMainForm = class(TForm)
    LogMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    InstallHook: TInstallHook;
    UninstallHook: TUninstallHook;
    EnterDominaMode: TProcedure;
    ExitDominaMode: TProcedure;
    KBHKLib: NativeUInt;
    FDominaWindows: TWindowList;
    WDKeyPressed: TBits;

    procedure SetDominaWindows(Value: TWindowList);
    procedure LogWindow(Window: THandle);

    procedure WD_EnterDominaMode(var Message: TMessage); message WD_ENTER_DOMINA_MODE;
    procedure WD_ExitDominaMode(var Message: TMessage); message WD_EXIT_DOMINA_MODE;
    procedure WD_KeyDownDominaMode(var Message: TMessage); message WD_KEYDOWN_DOMINA_MODE;
    procedure WD_KeyUpDominaMode(var Message: TMessage); message WD_KEYUP_DOMINA_MODE;

    property DominaWindows: TWindowList read FDominaWindows write SetDominaWindows;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FDominaWindows := TWindowList.Create;

  KBHKLib := LoadLibrary('kbhk.dll');
  if KBHKLib > 0 then
  begin
    InstallHook := GetProcAddress(KBHKLib, 'InstallHook');
    UnInstallHook := GetProcAddress(KBHKLib, 'UninstallHook');
    EnterDominaMode := GetProcAddress(KBHKLib, 'EnterDominaMode');
    ExitDominaMode := GetProcAddress(KBHKLib, 'ExitDominaMode');

    InstallHook(Handle)
  end
  else
    raise Exception.Create('Failed to load kbhk.dll');

  RegisterWDMKeyStates(TKeyStates.Create);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if KBHKLib > 0 then
  begin
    UninstallHook;
    FreeLibrary(KBHKLib);
  end;

  FDominaWindows.Free;
  WDKeyPressed.Free;
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
  LogMemo.Lines.Add(GetLogString(Window));
//  LogMemo.Lines.Add('-- GetAncestor(Window, GA_PARENT): ' + GetLogString(GetAncestor(Window, GA_PARENT)));
//  LogMemo.Lines.Add('-- GetAncestor(Window, GA_ROOT): ' + GetLogString(GetAncestor(Window, GA_ROOT)));
//  LogMemo.Lines.Add('-- GetAncestor(Window, GA_ROOTOWNER): ' + GetLogString(GetAncestor(Window, GA_ROOTOWNER)));
  LogMemo.Lines.Add('-- Style: ' + WindowStyleToString(GetWindowLong(Window, GWL_STYLE)));
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

procedure TMainForm.SetDominaWindows(Value: TWindowList);
begin
  FDominaWindows.Clear;
  FDominaWindows.AddRange(Value);
end;

function EnumAppWindowsProc(Window: THandle; Target: Pointer): Boolean; stdcall;
var
  WindowsList: TWindowList absolute Target;
  WindowStyle: NativeInt;
  Rect: TRect;

  function HasStyle(CheckMask: NativeInt): Boolean;
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
//  FGWindow, ParentWindow: HWND;
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

    DominaWindows := AppWins;
  finally
    AppWins.Free;
  end;

//  FGWindow := GetForegroundWindow;
//  LogMemo.Lines.Add('ForegroundWindow:');
//  LogWindow(FGWindow);
//
//  if HasParentWindow(FGWindow, ParentWindow) then
//  begin
//    LogMemo.Lines.Add('ParentWindow:');
//    LogWindow(ParentWindow);
//  end;
end;

procedure TMainForm.WD_ExitDominaMode(var Message: TMessage);
begin
  Caption := 'Normaler Modus';
  WDMKeyStates.ReleaseAllKeys;
end;

procedure TMainForm.WD_KeyDownDominaMode(var Message: TMessage);

  procedure SizeWindowTile(TileX, TileY: Integer);
  var
    Window: THandle;
    Rect, WorkareaRect: TRect;
    WAWidth, WAHeight, TileWidth, TileHeight: Integer;
  begin
    if DominaWindows.Count = 0 then
      Exit;

    Window := DominaWindows[0];
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

  procedure MoveSizeWindow(DeltaX, DeltaY: Integer);
  var
    Window: THandle;
    FastMode: Boolean;
    FMStepX, FMStepY: Integer;
    Rect, WorkareaRect: TRect;

    procedure AdjustForFastModeStep(var TargetVar: Integer; Step: Integer);
    begin
      TargetVar := (TargetVar div Step) * Step;
    end;

  begin
    if DominaWindows.Count = 0 then
      Exit;

    Window := DominaWindows[0];
    GetWindowRect(Window, Rect);
    WorkareaRect := GetWorkareaRect(Rect);

    FastMode := not WDMKeyStates.IsShiftKeyPressed;

    if FastMode then
    begin
      FMStepX := (WorkareaRect.Width div 100);
      FMStepY := (WorkareaRect.Height div 100);
      DeltaX := DeltaX * FMStepX;
      DeltaY := DeltaY * FMStepY;
    end
    else
    begin
      FMStepX := 0;
      FMStepY := 0;
    end;

    if WDMKeyStates.IsControlKeyPressed then
    begin
      if FastMode then
      begin
        if DeltaX <> 0 then
          AdjustForFastModeStep(Rect.Right, FMStepX);
        if DeltaY <> 0 then
          AdjustForFastModeStep(Rect.Bottom, FMStepY);
      end;

      Inc(Rect.Right, DeltaX);
      Inc(Rect.Bottom, DeltaY);
      SetWindowPos(Window, 0, 0, 0, Rect.Width, Rect.Height, SWP_NOZORDER or SWP_NOMOVE);
    end
    else
    begin
      if FastMode then
      begin
        if DeltaX <> 0 then
          AdjustForFastModeStep(Rect.Left, FMStepX);
        if DeltaY <> 0 then
          AdjustForFastModeStep(Rect.Top, FMStepY);
      end;

      Inc(Rect.Left, DeltaX);
      Inc(Rect.Top, DeltaY);
      SetWindowPos(Window, 0, Rect.Left, Rect.Top, 0, 0, SWP_NOZORDER or SWP_NOSIZE);
    end;
  end;

begin
  WDMKeyStates.KeyPressed[Message.WParam] := True;

  case Message.WParam of
    VK_ESCAPE:
      ExitDominaMode;
    VK_LEFT:
      MoveSizeWindow(-1, 0);
    VK_RIGHT:
      MoveSizeWindow(1, 0);
    VK_UP:
      MoveSizeWindow(0, -1);
    VK_DOWN:
      MoveSizeWindow(0, 1);
    VK_NUMPAD1:
      SizeWindowTile(0, 2);
    VK_NUMPAD2:
      SizeWindowTile(1, 2);
    VK_NUMPAD3:
      SizeWindowTile(2, 2);
    VK_NUMPAD4:
      SizeWindowTile(0, 1);
    VK_NUMPAD5:
      SizeWindowTile(1, 1);
    VK_NUMPAD6:
      SizeWindowTile(2, 1);
    VK_NUMPAD7:
      SizeWindowTile(0, 0);
    VK_NUMPAD8:
      SizeWindowTile(1, 0);
    VK_NUMPAD9:
      SizeWindowTile(2, 0);
  end;
end;

procedure TMainForm.WD_KeyUpDominaMode(var Message: TMessage);
begin
  WDMKeyStates.KeyPressed[Message.WParam] := False;
end;

end.
