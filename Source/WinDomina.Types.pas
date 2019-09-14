unit WinDomina.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms;

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

  TWindowList = TList<THandle>;

// Private Message types
const
  WD_ENTER_DOMINA_MODE = WM_USER + 69;
  WD_EXIT_DOMINA_MODE = WM_USER + 70;
  WD_KEYDOWN_DOMINA_MODE = WM_USER + 71;
  WD_KEYUP_DOMINA_MODE = WM_USER + 72;

type
  TDirection = (dirUnknown, dirUp, dirRight, dirDown, dirLeft);
  TRectEdge = (reUnknown, reTop, reRight, reBottom, reLeft);

  TKeyStates = class
  protected
    States: TBits;

    procedure SetKeyPressed(Key: Integer; State: Boolean);
    function GetKeyPressed(Key: Integer): Boolean;

  public
    destructor Destroy; override;

    function IsShiftKeyPressed: Boolean;
    function IsControlKeyPressed: Boolean;
    function IsAltKeyPressed: Boolean;

    procedure ReleaseAllKeys;

    property KeyPressed[Key: Integer]: Boolean read GetKeyPressed write SetKeyPressed;
  end;

  IMonitorHandler = interface
    ['{3A878286-2948-47C1-A9F7-F356ABB7F4CD}']

    function HasAdjacentMonitor(Direction: TDirection; out Monitor: TMonitor): Boolean;
    function HasNextMonitor(out Monitor: TMonitor): Boolean;
    function HasPrevMonitor(out Monitor: TMonitor): Boolean;

    function ClientToScreen(const Point: TPoint): TPoint; overload;
    function ScreenToClient(const Point: TPoint): TPoint; overload;
    function ClientToScreen(const Rect: TRect): TRect; overload;
    function ScreenToClient(const Rect: TRect): TRect; overload;

    function GetCurrentMonitor: TMonitor;
    procedure SetCurrentMonitor(Monitor: TMonitor);

    property CurrentMonitor: TMonitor read GetCurrentMonitor write SetCurrentMonitor;
  end;

  ILogging = interface
    ['{CCEF1BD9-1233-4B1C-84C0-863AE319FACB}']

    procedure AddLog(const LogLine: string);
    function HasWindowHandle(out Handle: HWND): Boolean;
  end;

  TStringsLogging = class(TInterfacedObject, ILogging)
  protected
    FStrings: TStrings;

    procedure AddLog(const LogLine: string);
    function HasWindowHandle(out Handle: HWND): Boolean;

  public
    WindowHandle: HWND;

    constructor Create(Target: TStrings);
  end;

  TRuntimeInfo = class
  public
    DefaultPath: string;
    CommonPath: string;
  end;

implementation

{ TKeyStates }

destructor TKeyStates.Destroy;
begin
  States.Free;

  inherited Destroy;
end;

procedure TKeyStates.SetKeyPressed(Key: Integer; State: Boolean);
begin
  if not Assigned(States) then
  begin
    States := TBits.Create;
    States.Size := 1024;
  end;
  if Key < States.Size then
    States.Bits[Key] := State;
end;

function TKeyStates.GetKeyPressed(Key: Integer): Boolean;
begin
  Result := Assigned(States) and (Key < States.Size) and States.Bits[Key];
end;

function TKeyStates.IsShiftKeyPressed: Boolean;
begin
  Result := KeyPressed[vkLShift] or KeyPressed[vkRShift];
end;

function TKeyStates.IsControlKeyPressed: Boolean;
begin
  Result := KeyPressed[vkLControl] or KeyPressed[vkRControl];
end;

function TKeyStates.IsAltKeyPressed: Boolean;
begin
  Result := KeyPressed[vkLMenu] or KeyPressed[vkRMenu];
end;

procedure TKeyStates.ReleaseAllKeys;
begin
  FreeAndNil(States);
end;

{ TStringsLogging }

constructor TStringsLogging.Create(Target: TStrings);
begin
  FStrings := Target;
end;

procedure TStringsLogging.AddLog(const LogLine: string);
begin
  FStrings.Add(LogLine);
end;

function TStringsLogging.HasWindowHandle(out Handle: HWND): Boolean;
begin
  Result := WindowHandle <> 0;
  Handle := WindowHandle;
end;

end.
