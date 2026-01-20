unit WD.KBHKLib;

interface

uses
  System.SysUtils;

const
  KBHK_DLL = 'kbhk.dll';

function InstallHook(Hwnd: THandle): Boolean; stdcall; external KBHK_DLL;
function UninstallHook: Boolean; stdcall; external KBHK_DLL;
procedure EnterDominaMode; stdcall; external KBHK_DLL;
procedure ExitDominaMode; stdcall; external KBHK_DLL;
procedure ToggleDominaMode; stdcall; external KBHK_DLL;
procedure SetActivationKey(Key: Integer); stdcall; external KBHK_DLL;
function IsDominaModeActivated: Boolean; stdcall; external KBHK_DLL;

implementation

end.
