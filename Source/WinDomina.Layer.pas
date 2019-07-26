unit WinDomina.Layer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Winapi.D2D1,

  AnyiQuack,

  WinDomina.Types,
  WinDomina.Types.Drawing;

type
  TBaseLayer = class
  private
    class var
    MainContentLoopTimerID: Integer;
  private
    FOnMainContentChanged: TNotifyEvent;

    procedure DoMainContentChanged;

  protected
    FIsLayerActive: Boolean;
    MainContentChanged: Boolean;
    InvalidateMainContentLoopDepth: Integer;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);
    procedure ForceExitInvalidateMainContentLoop;

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

    procedure EnterInvalidateMainContentLoop;
    procedure ExitInvalidateMainContentLoop;

    function GetDisplayName: string; virtual;

    property IsLayerActive: Boolean read FIsLayerActive;

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
  ForceExitInvalidateMainContentLoop;
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
    DoMainContentChanged;
  end;
end;

procedure TBaseLayer.EnterInvalidateMainContentLoop;
begin
  if InvalidateMainContentLoopDepth = 0 then
  begin
    Take(Self)
      .CancelDelays(MainContentLoopTimerID)
      .EachInterval(10,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        Result := True;
        TBaseLayer(O).InvalidateMainContent;
      end, MainContentLoopTimerID);
  end;
  Inc(InvalidateMainContentLoopDepth);
end;

procedure TBaseLayer.ExitInvalidateMainContentLoop;
begin
  Dec(InvalidateMainContentLoopDepth);
  if InvalidateMainContentLoopDepth = 0 then
    Take(Self)
      .EachDelay(200,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        Take(O).CancelIntervals(MainContentLoopTimerID);
        Result := False;
      end, MainContentLoopTimerID)
  else if InvalidateMainContentLoopDepth < 0 then
    InvalidateMainContentLoopDepth := 0;
end;

procedure TBaseLayer.ForceExitInvalidateMainContentLoop;
begin
  InvalidateMainContentLoopDepth := 0;
  Take(Self).CancelIntervals(MainContentLoopTimerID);
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
