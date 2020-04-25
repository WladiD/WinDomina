unit WD.Registry;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  
  WD.Types,
  WD.Layer,
  WD.WindowPositioner,
  WD.KeyTools;

// WDMKeyStates protokolliert den Zustand der Tasten im WinDomina-Modus
procedure RegisterWDMKeyStates(States: TKeyStates);
function WDMKeyStates: TKeyStates;

// LayerActivationKeys hält eine Liste zwischen den Aktivierungstasten und dem entsprechenden Layer
procedure RegisterLayerActivationKeys(List: TKeyLayerList);
function LayerActivationKeys: TKeyLayerList;

// KISS Logging-System
procedure RegisterLogging(Log: ILogging);
procedure AddLog(const LogLine: string);
function Logging: ILogging;

function RuntimeInfo: TRuntimeInfo;

procedure RegisterWindowPositioner(Positioner: TWindowPositioner);
function WindowPositioner: TWindowPositioner;

procedure RegisterKeyRenderManager(KRM: TKeyRenderManager);
function KeyRenderManager: TKeyRenderManager;

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

var
  WP: TWindowPositioner;

procedure RegisterWindowPositioner(Positioner: TWindowPositioner);
begin
  WP.Free;
  WP := Positioner;
end;

function WindowPositioner: TWindowPositioner;
begin
  Result := WP;
end;

var
  GlobalKeyRenderManager: TKeyRenderManager;

procedure RegisterKeyRenderManager(KRM: TKeyRenderManager);
begin
  GlobalKeyRenderManager.Free;
  GlobalKeyRenderManager := KRM;
end;

function KeyRenderManager: TKeyRenderManager;
begin
  Result := GlobalKeyRenderManager;
end;

initialization

finalization
FreeAndNil(WDMKS);
FreeAndNil(LAK);
FreeAndNil(RI);
LogInterface := nil;
FreeAndNil(WP);
FreeAndNil(GlobalKeyRenderManager);

end.
