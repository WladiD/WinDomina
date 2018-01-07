unit WinDomina.Layer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Winapi.D2D1,
  WinDomina.Types,
  WinDomina.Types.Drawing;

type
  TBaseLayer = class
  private

  protected
    FIsLayerActive: Boolean;
    FOnMainContentChanged: TNotifyEvent;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);
    procedure DoMainContentChanged; virtual;

  public
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

    property IsLayerActive: Boolean read FIsLayerActive;

    // Dieses Ereignis wird ausgelöst, wenn der Layer selbst feststellt, dass er sich neu zeichnen
    // muss
    property OnMainContentChanged: TNotifyEvent read FOnMainContentChanged
      write FOnMainContentChanged;
  end;

  TKeyLayerList = TDictionary<Integer, TBaseLayer>;
  TLayerList = TObjectList<TBaseLayer>;
  TLayerStack = TStack<TBaseLayer>;

implementation

uses
  WinDomina.Registry;

{ TBaseLayer }

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

// Hier sollten die verwendeten Direct2D-Ressourcen verworfen werden, die evtl. beim zeichnen
// zwischengespeichert wurden
procedure TBaseLayer.InvalidateMainContentResources;
begin

end;

procedure TBaseLayer.DoMainContentChanged;
begin
  if Assigned(FOnMainContentChanged) then
    FOnMainContentChanged(Self);
end;

end.
