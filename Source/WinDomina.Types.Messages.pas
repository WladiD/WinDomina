unit WinDomina.Types.Messages;

interface

uses
  Winapi.Windows,
  Winapi.Messages;

type
  // Structure used by WH_KEYBOARD_LL
  KBDLLHOOKSTRUCT = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: DWORD;
  end;
  PKBDLLHOOKSTRUCT = ^KBDLLHOOKSTRUCT;

// Private Message types
const
  WD_ENTER_DOMINA_MODE = WM_USER + 69;
  WD_EXIT_DOMINA_MODE = WM_USER + 70;
  WD_KEYDOWN_DOMINA_MODE = WM_USER + 71;
  WD_KEYUP_DOMINA_MODE = WM_USER + 72;

implementation

end.
