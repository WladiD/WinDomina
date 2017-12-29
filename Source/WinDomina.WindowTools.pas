unit WinDomina.WindowTools;

interface

uses
  System.SysUtils,
  System.Types,
  System.StrUtils,
  Vcl.Forms,
  Winapi.Windows;

function GetWorkareaRect(const RefRect: TRect): TRect; overload;
function GetWorkareaRect(RefWindow: THandle): TRect; overload;

function WindowStyleToString(Style: Long): string;

implementation

function GetWorkareaRect(const RefRect: TRect): TRect;
begin
  Result := Screen.MonitorFromRect(RefRect).WorkareaRect;
end;

function GetWorkareaRect(RefWindow: THandle): TRect;
var
  WindowRect: TRect;
begin
  if GetWindowRect(RefWindow, WindowRect) then
    Result := GetWorkareaRect(WindowRect)
  else
    Result := TRect.Empty;
end;

// Converts the window style flags to human readable representation in a string
// @see <https://msdn.microsoft.com/de-de/library/windows/desktop/ms632600(v=vs.85).aspx>
function WindowStyleToString(Style: Long): string;

  procedure AppendFlag(Mask: Long; FlagName: string);
  begin
    if (Style and Mask) = Mask then
      Result := Result + IfThen(Result <> '', ', ') + FlagName;
  end;

begin
  AppendFlag(WS_BORDER, 'WS_BORDER');
  AppendFlag(WS_CAPTION, 'WS_CAPTION');
  AppendFlag(WS_CHILD, 'WS_CHILD');
  AppendFlag(WS_CLIPCHILDREN, 'WS_CLIPCHILDREN');
  AppendFlag(WS_CLIPSIBLINGS, 'WS_CLIPSIBLINGS');
  AppendFlag(WS_DISABLED, 'WS_DISABLED');
  AppendFlag(WS_DLGFRAME, 'WS_DLGFRAME');
  AppendFlag(WS_GROUP, 'WS_GROUP');
  AppendFlag(WS_HSCROLL, 'WS_HSCROLL');
  AppendFlag(WS_MAXIMIZE, 'WS_MAXIMIZE');
  AppendFlag(WS_MAXIMIZEBOX, 'WS_MAXIMIZEBOX');
  AppendFlag(WS_MINIMIZE, 'WS_MINIMIZE');
  AppendFlag(WS_MINIMIZEBOX, 'WS_MINIMIZEBOX');
  AppendFlag(WS_OVERLAPPED, 'WS_OVERLAPPED');
  AppendFlag(WS_OVERLAPPEDWINDOW, 'WS_OVERLAPPEDWINDOW');
  AppendFlag(WS_POPUP, 'WS_POPUP');
  AppendFlag(WS_POPUPWINDOW, 'WS_POPUPWINDOW');
  AppendFlag(WS_SIZEBOX, 'WS_SIZEBOX');
  AppendFlag(WS_SYSMENU, 'WS_SYSMENU');
  AppendFlag(WS_TABSTOP, 'WS_TABSTOP');
  AppendFlag(WS_VISIBLE, 'WS_VISIBLE');
  AppendFlag(WS_VSCROLL, 'WS_VSCROLL');
end;

end.
