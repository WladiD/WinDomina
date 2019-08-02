unit WinDomina.Registry;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  WinDomina.Types,
  WinDomina.Layer;

// WDMKeyStates protokolliert den Zustand der Tasten im WinDomina-Modus
procedure RegisterWDMKeyStates(States: TKeyStates);
function WDMKeyStates: TKeyStates;

// LayerActivationKeys hält eine Liste zwischen den Aktivierungstasten und dem entsprechenden Layer
procedure RegisterLayerActivationKeys(List: TKeyLayerList);
function LayerActivationKeys: TKeyLayerList;

// DominaWindows hält eine Liste von Fenstern, die sich aktuell unter Kontrolle von WinDomina
// befinden
procedure RegisterDominaWindows(DominaWindows: TWindowList);
function DominaWindows: TWindowList;
procedure BroadcastDominaWindowsChangeNotify;
procedure RegisterDominaWindowsChangeNotify(EventHandler: TProc; Implementor: TObject);
procedure UnregisterDominaWindowsChangeNotify(Implementor: TObject);

// KISS Logging-System
procedure RegisterLogging(Log: ILogging);
procedure AddLog(const LogLine: string);
function Logging: ILogging;

function RuntimeInfo: TRuntimeInfo;

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

threadvar
  LAK: TKeyLayerList;

procedure RegisterLayerActivationKeys(List: TKeyLayerList);
begin
  LAK.Free;
  LAK := List;
end;

function LayerActivationKeys: TKeyLayerList;
begin
  Result := LAK;
end;

type
  TDWChangeEventsDictionary = TDictionary<TObject, TProc>;

threadvar
  DW: TWindowList;
  DWChangeEvents: TDWChangeEventsDictionary;

procedure RegisterDominaWindows(DominaWindows: TWindowList);
begin
  DW.Free;
  DW := DominaWindows;
end;

function DominaWindows: TWindowList;
begin
  Result := DW;
end;

procedure BroadcastDominaWindowsChangeNotify;
var
  EventHandler: TProc;
begin
  for EventHandler in DWChangeEvents.Values do
    EventHandler;
end;

procedure RegisterDominaWindowsChangeNotify(EventHandler: TProc; Implementor: TObject);
begin
  DWChangeEvents.AddOrSetValue(Implementor, EventHandler);
end;

procedure UnregisterDominaWindowsChangeNotify(Implementor: TObject);
begin
  DWChangeEvents.Remove(Implementor);
end;

var
  LogInterface: ILogging;

procedure RegisterLogging(Log: ILogging);
begin
  LogInterface := Log;
end;

procedure AddLog(const LogLine: string);
begin
  if Assigned(LogInterface) then
    LogInterface.AddLog(LogLine);
end;

function Logging: ILogging;
begin
  Result := LogInterface;
end;

var
  RI: TRuntimeInfo;

function RuntimeInfo: TRuntimeInfo;
begin
  if not Assigned(RI) then
    RI := TRuntimeInfo.Create;
  Result := RI;
end;

initialization
DWChangeEvents := TDWChangeEventsDictionary.Create;

finalization
FreeAndNil(WDMKS);
FreeAndNil(LAK);
FreeAndNil(DWChangeEvents);
FreeAndNil(DW);
FreeAndNil(RI);
LogInterface := nil;

end.
