unit WinDomina.Registry;

interface

uses
  System.SysUtils,
  WinDomina.Types;

// WDMKeyStates protokolliert den Zustand der Tasten im WinDomina-Modus
procedure RegisterWDMKeyStates(States: TKeyStates);
function WDMKeyStates: TKeyStates;

implementation

threadvar
  WDMKS: TKeyStates;

procedure RegisterWDMKeyStates(States: TKeyStates);
begin
  WDMKS.Free;
  WDMKS := States;
end;

function WDMKeyStates: TKeyStates;
begin
  Result := WDMKS;
end;

end.
