// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.KBHKLib;

interface

uses

  System.SysUtils,
  WD.Types.Actions;

const

  KBHK_DLL = 'kbhk.dll';

procedure EnterDominaMode; stdcall; external KBHK_DLL;
procedure ExitDominaMode; stdcall; external KBHK_DLL;
function  InstallHook(Hwnd: THandle): Boolean; stdcall; external KBHK_DLL;
function  IsDominaModeActivated: Boolean; stdcall; external KBHK_DLL;
procedure SetCapsLockAction(Action: TCapsLockAction); stdcall; external KBHK_DLL;
procedure SetLeftWinAction(Action: TLeftWinAction); stdcall; external KBHK_DLL;
procedure SetRightCtrlAction(Action: TRightCtrlAction); stdcall; external KBHK_DLL;
procedure ToggleDominaMode; stdcall; external KBHK_DLL;
function  UninstallHook: Boolean; stdcall; external KBHK_DLL;

implementation

end.
