unit WinDomina.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
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

  TWindowList = TList<THandle>;

// Private Message types
const
  WD_ENTER_DOMINA_MODE = WM_USER + 69;
  WD_EXIT_DOMINA_MODE = WM_USER + 70;
  WD_KEYDOWN_DOMINA_MODE = WM_USER + 71;
  WD_KEYUP_DOMINA_MODE = WM_USER + 72;

type
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

  ILogging = interface
    ['{CCEF1BD9-1233-4B1C-84C0-863AE319FACB}']

    procedure AddLog(const LogLine: string);
  end;

  TStringsLogging = class(TInterfacedObject, ILogging)
  protected
    FStrings: TStrings;

    procedure AddLog(const LogLine: string);
  public
    constructor Create(Target: TStrings);
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

end.
