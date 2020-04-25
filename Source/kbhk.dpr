library kbhk;

uses
  Winapi.Messages,
  Winapi.Windows,
  WD.Types.Messages;

{$R *.res}

// This code based on the tutorial:
// <https://www.delphi-treff.de/tutorials/systemnahe-programmierung/mouse-und-tastatur-hooks/>

var
  HookHandle: NativeUInt;
  WindowHandle: NativeUInt;
  DoubleTapTime: NativeUInt;
  DominaHotkey: DWORD = VK_CAPITAL;
  LastHotkeyTapTick: UInt64;
  DominaModeActivated: Boolean;

procedure EnterDominaMode; stdcall;
begin
  if not DominaModeActivated then
  begin
    DominaModeActivated := True;
    PostMessage(WindowHandle, WD_ENTER_DOMINA_MODE, 0, 0);
  end;
end;

procedure ExitDominaMode; stdcall;
begin
  if DominaModeActivated then
  begin
    DominaModeActivated := False;
    PostMessage(WindowHandle, WD_EXIT_DOMINA_MODE, 0, 0);
  end;
end;

procedure ToggleDominaMode; stdcall;
begin
  if DominaModeActivated then
    ExitDominaMode
  else
    EnterDominaMode;
end;

function IsDominaModeActivated: Boolean; stdcall;
begin
  Result := DominaModeActivated;
end;

function LowLevelKeyboardHookProc(nCode: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  PKH: PKBDLLHOOKSTRUCT absolute lParam;
  NextHook: Boolean;
  CurrentTick: UInt64;
begin
  if nCode < 0 then
  begin
    Result := CallNextHookEx(HookHandle, nCode, wParam, lParam);
    Exit;
  end;

  Result := 1;
  NextHook := True;
  try
    if (wParam = WM_KEYUP) and (PKH.vkCode = DominaHotkey) then
    begin
      CurrentTick := GetTickCount64;
      if LastHotkeyTapTick > (CurrentTick - DoubleTapTime) then
      begin
        ToggleDominaMode;
        LastHotkeyTapTick := 0;
      end
      else
        LastHotkeyTapTick := CurrentTick;
    end
    // Im Domina-Modus werden alle Tastendrücke abgefangen und umgeleitet
    else if DominaModeActivated then
    begin
      NextHook := False;
      case wParam of
        WM_KEYDOWN,
        WM_SYSKEYDOWN:
          PostMessage(WindowHandle, WD_KEYDOWN_DOMINA_MODE, PKH.vkCode, PKH.flags);
        WM_KEYUP,
        WM_SYSKEYUP:
          PostMessage(WindowHandle, WD_KEYUP_DOMINA_MODE, PKH.vkCode, PKH.flags);
      else
        NextHook := True;
      end;
    end;

    // Wenn die standardmäßige [CapsLock]-Taste als Hotkey verwendet wird, dann leiten wir den
    // Hook nicht weiter und deaktivieren somit die Taste. Die CapsLock-Statusanzeige wird auf
    // diese Weise auch umgangen.
    if NextHook and (DominaHotkey = VK_CAPITAL) and (PKH.vkCode = VK_CAPITAL) and
      // Der Hook wird aber einmalig weitergeleitet, wenn die [CapsLock]-Taste aktuell
      // festgestellt ist, damit es deaktiviert wird.
      ((GetKeyState(VK_CAPITAL) and $1) = 0) then
      NextHook := False;
  finally
    if NextHook then
      Result := CallNextHookEx(HookHandle, nCode, wParam, lParam);
  end;
end;

function InstallHook(Hwnd: Cardinal): Boolean; stdcall;
begin
  Result := False;
  if HookHandle = 0 then
  begin
    HookHandle := SetWindowsHookEx(WH_KEYBOARD_LL, @LowLevelKeyboardHookProc, HInstance, 0);
    WindowHandle := Hwnd;
    DoubleTapTime := GetDoubleClickTime;
    Result := True;
  end;
end;

function UninstallHook: Boolean; stdcall;
begin
  if HookHandle > 0 then
  begin
    Result := UnhookWindowsHookEx(HookHandle);
    HookHandle := 0;
  end
  else
    Result := False;
end;

exports
  InstallHook,
  UninstallHook,
  EnterDominaMode,
  ExitDominaMode,
  ToggleDominaMode,
  IsDominaModeActivated;
end.
