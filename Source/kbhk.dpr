// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

library kbhk;

uses

  Winapi.Messages,
  Winapi.Windows,

  WD.Types.Messages,
  WD.Types.Actions;

{$R *.res}

var

  HookHandle: NativeUInt;
  WindowHandle: NativeUInt;
  DoubleTapTime: NativeUInt;

  DominaModeActivated: Boolean;

  // Configuration
  CapsLockAction : TCapsLockAction = claActivateWD;
  LeftWinAction  : TLeftWinAction  = lwaActivateWD;
  RightCtrlAction: TRightCtrlAction = rcaDoNothing;

  // State
  LastCapsLockTapTick : UInt64;
  LastLeftWinTapTick  : UInt64;
  LastRightCtrlTapTick: UInt64;
  LastLeftWinWasStartMenu: Boolean;

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

procedure SetCapsLockAction(Action: TCapsLockAction); stdcall;
begin
  CapsLockAction := Action;
end;

procedure SetLeftWinAction(Action: TLeftWinAction); stdcall;
begin
  LeftWinAction := Action;
end;

procedure SetRightCtrlAction(Action: TRightCtrlAction); stdcall;
begin
  RightCtrlAction := Action;
end;

function IsDominaModeActivated: Boolean; stdcall;
begin
  Result := DominaModeActivated;
end;

function IsStartMenuActive: Boolean;
var
  ClassName: Array[0..255] of Char;
  FgHandle : HWND;
  FgPid    : DWORD;
  Title    : Array[0..255] of Char;
  TrayPid  : DWORD;
begin
  Result := False;
  FgHandle := GetForegroundWindow;
  if FgHandle = 0 then
    Exit;

  // 1. Check if foreground window belongs to the same process as the Taskbar (Explorer.exe)
  if (GetWindowThreadProcessId(FgHandle, FgPid) <> 0) and
     (GetWindowThreadProcessId(FindWindow('Shell_TrayWnd', nil), TrayPid) <> 0) and
     (FgPid = TrayPid) and
     (TrayPid <> 0) and
     (GetClassName(FgHandle, ClassName, 255) > 0) and
     (lstrcmpiW(ClassName, 'Progman') <> 0) and  // The Desktop (Progman/WorkerW) is NOT the Start menu.
     (lstrcmpiW(ClassName, 'WorkerW') <> 0) then
    Exit(True);

  // 2. Check for UWP Start menu/Search hosts and other shell classes
  if GetClassName(FgHandle, ClassName, 255) > 0 then
  begin
    // Windows 10/11 Start (often CoreWindow)
    if (lstrcmpiW(ClassName, 'Windows.UI.Core.CoreWindow') = 0) and
       (GetWindowText(FgHandle, Title, 255) > 0) and
       (
         (lstrcmpiW(Title, 'Start') = 0) or
         (lstrcmpiW(Title, 'Search') = 0) or
         (lstrcmpiW(Title, 'Suche') = 0)
       ) then
      Exit(True);

    Result :=
      (lstrcmpiW(ClassName, 'XamlExplorerHostIslandWindow') = 0) or  // Windows 11 Shell / Search
      (lstrcmpiW(ClassName, 'DV2ControlHost') = 0);                  // Windows 7 Start Menu
  end;
end;

procedure SendContextMenuKey;
var
  Inputs: Array [0..1] of TInput;
begin
  ZeroMemory(@Inputs, SizeOf(Inputs));

  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_APPS;

  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := VK_APPS;
  Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(2, Inputs[0], SizeOf(TInput));
end;

function LowLevelKeyboardHookProc(nCode: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  CurrentTick       : UInt64;
  NextHook          : Boolean;
  PKH               : PKBDLLHOOKSTRUCT absolute lParam;
  SuppressForwarding: Boolean;
begin
  if nCode < 0 then
  begin
    Result := CallNextHookEx(HookHandle, nCode, wParam, lParam);
    Exit;
  end;

  Result := 1;
  NextHook := True;
  SuppressForwarding := False;

  try
    if (wParam = WM_KEYUP) then
    begin
      CurrentTick := GetTickCount64;

      // --- CapsLock Handling ---
      if (PKH.vkCode = VK_CAPITAL) and (CapsLockAction <> claDoNothing) then
      begin
        if LastCapsLockTapTick > (CurrentTick - DoubleTapTime) then
        begin
          ToggleDominaMode;
          LastCapsLockTapTick := 0;
        end
        else
          LastCapsLockTapTick := CurrentTick;

        SuppressForwarding := True;
      end

      // --- LeftWin Handling ---
      else if (PKH.vkCode = VK_LWIN) and (LeftWinAction = lwaActivateWD) then
      begin
        if LastLeftWinTapTick > (CurrentTick - DoubleTapTime) then
        begin
          if not LastLeftWinWasStartMenu then
            ToggleDominaMode;
          LastLeftWinTapTick := 0;
        end
        else
        begin
          LastLeftWinTapTick := CurrentTick;
          LastLeftWinWasStartMenu := IsStartMenuActive;
        end;

        SuppressForwarding := True;
      end

      // --- RightCtrl Handling ---
      else if (PKH.vkCode = VK_RCONTROL) and (RightCtrlAction = rcaContextMenu) then
      begin
        if LastRightCtrlTapTick > (CurrentTick - DoubleTapTime) then
        begin
          SendContextMenuKey;
          LastRightCtrlTapTick := 0;
        end
        else
          LastRightCtrlTapTick := CurrentTick;

        // RightCtrl should be forwarded as it also serves as a modifier
        SuppressForwarding := False;
      end;
    end;

    // In Domina mode, all key presses are intercepted and redirected
    // Exception: If the event was marked as "to be suppressed" above (activation keys)
    if DominaModeActivated and not SuppressForwarding then
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

    // Suppress hotkey (only CapsLock support for Ignore Key)
    if NextHook and (PKH.vkCode = VK_CAPITAL) then
    begin
      if (CapsLockAction = claActivateWDIgnoreKey) then
      begin
        // If the standard [CapsLock] key is used as a hotkey, we do not forward the hook,
        // thus disabling the key. The CapsLock status indicator is also bypassed this way.
        // However, the hook is forwarded once if the [CapsLock] key is currently toggled on,
        // so that it gets deactivated.
        if (GetKeyState(VK_CAPITAL) and $1) = 0 then
          NextHook := False;
      end;
    end;
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
  SetCapsLockAction,
  SetLeftWinAction,
  SetRightCtrlAction,
  IsDominaModeActivated;
end.
