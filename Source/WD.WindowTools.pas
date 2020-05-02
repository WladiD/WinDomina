unit WD.WindowTools;

interface

uses
  System.SysUtils,
  System.Types,
  System.StrUtils,
  Vcl.Forms,
  Vcl.Controls,
  Winapi.Windows,
  Winapi.Dwmapi,

  SendInputHelper;

function GetWorkareaRect(const RefRect: TRect): TRect; overload;
function GetWorkareaRect(RefWindow: THandle): TRect; overload;

function WindowStyleToString(Style: Long): string;

function GetWindowRectDominaStyle(Window: THandle; out Rect: TRect): Boolean;
function GetWindowNonClientOversize(Window: THandle): TRect;
function SetWindowPosDominaStyle(hWnd, hWndInsertAfter: THandle; Rect: TRect; Flags: Cardinal): Boolean;
procedure BringWindowToTop(Window: THandle);

procedure SwitchToPreviouslyFocusedAppWindow;
function GetTaskbarHandle: THandle;
function FindWindowFromPoint(const Point: TPoint): HWND;

function NoSnap(A, B: Integer): Boolean;
function Snap(A, B: Integer): Boolean;
function SnapRect(const A, B: TRect): Boolean;

type
  TUpdateLayeredWindowInfo = record
    cbSize: DWORD;
    hdcDst: HDC;
    pptDst: PPoint;
    psize: PSize;
    hdcSrc: HDC;
    pptSrc: PPoint;
    crKey: TColorRef;
    pblend: PBlendFunction;
    dwFlags: DWORD;
    prcDirty: PRect;
  end;
  PUpdateLayeredWindowInfo = ^TUpdateLayeredWindowInfo;

function UpdateLayeredWindowIndirect(Handle: THandle; Info: PUpdateLayeredWindowInfo): Boolean; stdcall;
  external user32;

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

  procedure AppendFlag(Mask: FixedUInt; FlagName: string);
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

type
  TWindowInfo = record
    InitializedWindow: THandle;
    DropShadowSize: TRect;
    WindowSizeable: Boolean;
  end;

var
  WindowInfo: TWindowInfo;

procedure InitWindowInfo(Window: THandle);
var
  Success: Boolean;
  Rect, LegacyRect: TRect;
  WindowStyle: NativeInt;
begin
  if WindowInfo.InitializedWindow = Window then
    Exit;

  WindowInfo.InitializedWindow := Window;

  // Initialize DropShadowSize on Windows Vista or later
  if TOSVersion.Check(6) then
  begin
    Success := (DwmGetWindowAttribute(Window, DWMWA_EXTENDED_FRAME_BOUNDS,
      @Rect, SizeOf(Rect)) = S_OK) and GetWindowRect(Window, LegacyRect);

    if Success then
    begin
      WindowInfo.DropShadowSize.Left := LegacyRect.Left - Rect.Left;
      WindowInfo.DropShadowSize.Right := LegacyRect.Right - Rect.Right;
      WindowInfo.DropShadowSize.Top := LegacyRect.Top - Rect.Top;
      WindowInfo.DropShadowSize.Bottom := LegacyRect.Bottom - Rect.Bottom;
    end
    else
      WindowInfo.DropShadowSize := TRect.Empty;
  end;

  WindowStyle := GetWindowLong(Window, GWL_STYLE);
  WindowInfo.WindowSizeable := (WindowStyle and WS_SIZEBOX) <> 0;
end;

// GetWindowRect liefert das Fensterrechteck inkl. ggf vorhandenem Fensterschatten. Diese Funktion
// zieht den Schatten vom Rechteck ab und liefert das effektiv genutzte Fenster.
function GetWindowRectDominaStyle(Window: THandle; out Rect: TRect): Boolean;
begin
  InitWindowInfo(Window);

  Result := GetWindowRect(Window, Rect);
  // Extend the given rect by shadow
  if not WindowInfo.DropShadowSize.IsEmpty then
  begin
    Dec(Rect.Left, WindowInfo.DropShadowSize.Left);
    Dec(Rect.Top, WindowInfo.DropShadowSize.Top);
    Dec(Rect.Right, WindowInfo.DropShadowSize.Right);
    Dec(Rect.Bottom, WindowInfo.DropShadowSize.Bottom);
  end;
end;

function GetWindowNonClientOversize(Window: THandle): TRect;
begin
  InitWindowInfo(Window);
  Result := WindowInfo.DropShadowSize;
end;

function SetWindowPosDominaStyle(hWnd, hWndInsertAfter: THandle; Rect: TRect;
  Flags: Cardinal): Boolean;
var
  NoSizeFlag: Boolean;
begin
  InitWindowInfo(hWnd);

  NoSizeFlag := (Flags and SWP_NOSIZE) <> 0;

  // Extend the given rect by shadow
  if not WindowInfo.DropShadowSize.IsEmpty then
  begin
    // Flag not present?
    if (Flags and SWP_NOMOVE) = 0 then
    begin
      Inc(Rect.Left, WindowInfo.DropShadowSize.Left);
      Inc(Rect.Top, WindowInfo.DropShadowSize.Top);
    end;

    if not NoSizeFlag then
    begin
      Inc(Rect.Right, WindowInfo.DropShadowSize.Right);
      Inc(Rect.Bottom, WindowInfo.DropShadowSize.Bottom);
    end;
  end;

  // If the window is not sizeable, add the SWP_NOSIZE flag
  if not NoSizeFlag and not WindowInfo.WindowSizeable then
    Flags := Flags or SWP_NOSIZE;

  Result := Winapi.Windows.SetWindowPos(hWnd, hWndInsertAfter, Rect.Left, Rect.Top,
    Rect.Width, Rect.Height, Flags);
end;

procedure BringWindowToTop(Window: THandle);
begin
  SetWindowPos(Window, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);
  SetWindowPos(Window, HWND_NOTOPMOST, 0, 0, 0, 0,
    SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);

  // Die folgende Variante hat auch funktioniert, ist aber ineffizient und fasst mehr
  // (eigentlich unbeteiligte) Fenster an. Aber vielleicht braucht man das einmal...
//    DominaTargets := DominaTargets.Clone;
//    try
//      SwitchTargetNewIndex := DominaTargets.IndexOf(SwitchTargetWindow.Handle);
//
//      for cc := 0 to SwitchTargetNewIndex - 1 do
//        if (cc < DominaTargets.Count) and Assigned(DominaTargets[cc]) then
//          SetWindowPos(DominaTargets[cc].Handle, SwitchTargetWindow.Handle, 0, 0, 0, 0,
//            SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);
//    finally
//      DominaTargets.Free;
//    end;
end;

procedure SwitchToPreviouslyFocusedAppWindow;
var
  SIH: TSendInputHelper;
begin
  SIH := TSendInputHelper.Create;
  try
    SIH.AddShift([ssAlt], True, False);
    SIH.AddDelay(50);
    SIH.AddVirtualKey(VK_TAB, True, False);
    SIH.AddDelay(50);
    SIH.AddVirtualKey(VK_TAB, False, True);
    SIH.AddShift([ssAlt], False, True);
    SIH.AddDelay(50);

    SIH.Flush;
  finally
    SIH.Free;
  end;
end;

function GetTaskbarHandle: THandle;
begin
  Result := FindWindow('Shell_TrayWnd', nil);
end;

// Sagt aus, ob der absolute Unterschied zwischen den beiden Parametern
// eine Mindestdifferenz erfüllt
function NoSnap(A, B: Integer): Boolean;
begin
  Result := Abs(A - B) >= 5;
end;

function Snap(A, B: Integer): Boolean;
begin
  Result := Abs(A - B) < 5;
end;

function SnapRect(const A, B: TRect): Boolean;
begin
  Result := Snap(A.Left, B.Left) and Snap(A.Top, B.Top) and
    Snap(A.Right, B.Right) and Snap(A.Bottom, B.Bottom);
end;

function IsDelphiHandle(Handle: HWND): Boolean;
var
  OwningProcess: DWORD;
begin
  Result := (Handle <> 0) and (GetWindowThreadProcessID(Handle, OwningProcess) <> 0) and
    (OwningProcess = GetCurrentProcessId) and (FindControl(Handle) <> nil);
end;

function FindWindowFromPoint(const Point: TPoint): HWND;
begin
  Result := WindowFromPoint(Point);
  while Result <> 0 do
    if not IsDelphiHandle(Result) then
      Result := GetParent(Result)
    else
      Exit;
end;

end.
