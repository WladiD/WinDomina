unit WinDomina.Layer;

interface

uses
  Winapi.D2D1,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,

  AnyiQuack,

  WinDomina.Types,
  WinDomina.Types.Drawing;

type
  TBaseLayer = class
  private
    class var
    MainContentLoopTimerID: Integer;
    LayerInvalidateDelayID: Integer;
  private
    FOnMainContentChanged: TNotifyEvent;

    procedure DoMainContentChanged;

  protected
    FIsLayerActive: Boolean;
    FMonitorHandler: IMonitorHandler;
    MainContentChanged: Boolean;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);

  public
    class constructor Create;
    constructor Create; virtual;
    destructor Destroy; override;

    procedure EnterLayer; virtual;
    procedure ExitLayer; virtual;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); virtual;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); virtual;

    function HasMainContent(const DrawContext: IDrawContext;
      var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean; virtual;
    procedure RenderMainContent(const DrawContext: IDrawContext;
      const LayerParams: TD2D1LayerParameters); virtual;
    procedure InvalidateMainContentResources; virtual;
    procedure InvalidateMainContent; virtual;

    function GetDisplayName: string; virtual;

    property IsLayerActive: Boolean read FIsLayerActive;
    property MonitorHandler: IMonitorHandler read FMonitorHandler write FMonitorHandler;
    // Dieses Ereignis wird ausgelöst, wenn der Layer selbst feststellt, dass er sich neu zeichnen
    // muss
    property OnMainContentChanged: TNotifyEvent read FOnMainContentChanged
      write FOnMainContentChanged;
  end;

  TBaseLayerClass = class of TBaseLayer;

  TKeyLayerList = TDictionary<Integer, TBaseLayer>;
  TLayerList = TObjectList<TBaseLayer>;
  TLayerStack = TStack<TBaseLayer>;

implementation

uses
  WinDomina.Registry;

{ TBaseLayer }

class constructor TBaseLayer.Create;
begin
  MainContentLoopTimerID := TAQ.GetUniqueID;
  LayerInvalidateDelayID := TAQ.GetUniqueID;
end;

constructor TBaseLayer.Create;
begin

end;

destructor TBaseLayer.Destroy;
begin

  inherited Destroy;
end;

procedure TBaseLayer.EnterLayer;
begin
  FIsLayerActive := True;
end;

procedure TBaseLayer.ExitLayer;
begin
  FIsLayerActive := False;
end;

// Registriert die Tasten, die zu einer Aktivierung des Layers führen
//
// Es ist irrelevant welcher Layer gerade aktiv ist, wenn die jeweilige Taste nicht vom aktiven
// Layer kosumiert wurde, wird sie für die Aktivierung verwendet.
procedure TBaseLayer.RegisterLayerActivationKeys(Keys: array of Integer);
var
  Key: Integer;
  List: TKeyLayerList;
begin
  List := LayerActivationKeys;
  for Key in Keys do
    List.Add(Key, Self);
end;

procedure TBaseLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);
begin
  Handled := False;
end;

procedure TBaseLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin
  Handled := False;
end;

// Sagt aus, ob es einen Hauptinhalt gibt
//
// Wenn True zurückgeliefert wird, so kann (muss aber nicht) im Ausgabeparameter Layer eine
// Layer-Instanz zurückgegeben werden. Folglich wird in dem Fall die Methode RenderMainContent
// aufgerufen.
function TBaseLayer.HasMainContent(const DrawContext: IDrawContext;
  var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean;
begin
  Result := False;
end;

// Zeichnet den Hauptinhalt
procedure TBaseLayer.RenderMainContent(const DrawContext: IDrawContext;
  const LayerParams: TD2D1LayerParameters);
begin

end;

procedure TBaseLayer.DoMainContentChanged;
begin
  if Assigned(FOnMainContentChanged) then
    FOnMainContentChanged(Self);
  MainContentChanged := False;
end;

// Hier sollten die verwendeten Direct2D-Ressourcen verworfen werden, die evtl. beim zeichnen
// zwischengespeichert wurden.
// In den abgeleiteten Klassen sollte der inherited-Aufruf dieser Methode am Ende der abgeleiteten
// Prozedur erfolgen.
procedure TBaseLayer.InvalidateMainContent;
begin
  if not MainContentChanged then
  begin
    MainContentChanged := True;
    Take(Self)
      .CancelDelays(LayerInvalidateDelayID)
      .EachDelay(5,
        function(AQ: TAQ; O: TObject): Boolean
        begin
          DoMainContentChanged;
          Result := True;
        end, LayerInvalidateDelayID);
  end;
end;

// Liefert den Anzeigenamen des Layers, der auch dem Benutzer präsentiert werden kann
function TBaseLayer.GetDisplayName: string;
begin
  Result := Copy(ClassName, 2, Pos('Layer', ClassName) - 2);
end;

procedure TBaseLayer.InvalidateMainContentResources;
begin

end;

end.
