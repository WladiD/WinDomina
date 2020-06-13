unit WD.Layer;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Contnrs,
  System.Types,

  GR32,
  AnyiQuack,
  WindowEnumerator,

  WD.Types;

type
  TBaseLayer = class;
  TBaseLayerClass = class of TBaseLayer;
  TKeyLayerList = TDictionary<Integer, TBaseLayer>;
  TLayerList = TObjectList<TBaseLayer>;
  TLayerStack = TStack<TBaseLayer>;
  TAnimationBase = class;
  TAnimationList = TObjectList<TAnimationBase>;

  TGetLayerEvent = reference to function: TBaseLayer;

  // Verfügbar Fenster-Tracking-Features
  TWindowTracking = (
    // Änderung des Zielfensters
    // Entsprechende Methode des Layers: TBaseLayer.TargetWindowChanged
    wtTargetChanged,
    // Bewegung oder Größenänderung des Zielfensters
    // Entsprechende Methode des Layers: TBaseLayer.TargetWindowMoved
    wtTargetMoved,
    // Bewegung irgendeines Wechselzielfensters
    // Das Zielfenster ist hiervon ausgenommen.
    // Entsprechende Methode des Layers: TBaseLayer.SwitchTargetWindowMoved
    wtAnySwitchTargetMoved);
  TWindowTrackings = set of TWindowTracking;

  TBaseLayer = class(TComponent)
  private
    FOnMainContentChanged: TNotifyEvent;
    FAnimations: TAnimationList;
    FInvalidateMainContentLock: Boolean;
    FOnExitLayer: TNotifyEvent;
    FOnGetPrevLayer: TGetLayerEvent;

    procedure DoMainContentChanged;

  protected
    FIsLayerActive: Boolean;
    FMonitorHandler: IMonitorHandler;
    FWindowsHandler: IWindowsHandler;
    FExclusive: Boolean;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);

    function HasTargetWindow(out WindowHandle: HWND): Boolean; overload;
    function HasTargetWindow(out Window: TWindow): Boolean; overload;
    procedure InvalidateMainContent; virtual;
    function GetPrevLayer: TBaseLayer;

    procedure AddAnimation(Animation: TAnimationBase; Duration, AnimationID: Integer);

  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure EnterLayer; virtual;
    procedure ExitLayer; virtual;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); virtual;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); virtual;

    function HasMainContent: Boolean; virtual;
    procedure RenderMainContent(Target: TBitmap32); virtual;

    procedure TargetWindowChanged; virtual;
    procedure TargetWindowMoved; virtual;
    procedure SwitchTargetWindowMoved(WindowHandle: HWND); virtual;
    procedure Invalidate; virtual;

    function GetTargetWindowChangedDelay: Integer; virtual;
    function GetTargetWindowMovedDelay: Integer; virtual;
    function GetRequiredWindowTrackings: TWindowTrackings; virtual;

    function GetDisplayName: string; virtual;

    property IsLayerActive: Boolean read FIsLayerActive;
    // Exclusive layers suppress other layers behind them
    property Exclusive: Boolean read FExclusive;
    property MonitorHandler: IMonitorHandler read FMonitorHandler write FMonitorHandler;
    property WindowsHandler: IWindowsHandler read FWindowsHandler write FWindowsHandler;
    // This event is triggered when the layer itself determines that it must be redrawn
    property OnMainContentChanged: TNotifyEvent read FOnMainContentChanged
      write FOnMainContentChanged;
    // Will be fired in ExitLayer method
    property OnExitLayer: TNotifyEvent read FOnExitLayer write FOnExitLayer;
    // Will be fired in GetPrevLayer method to obtain the previous layer
    property OnGetPrevLayer: TGetLayerEvent read FOnGetPrevLayer write FOnGetPrevLayer;
  end;

  TAnimationBase = class
  protected
    FProgress: Real;
    FLayer: TBaseLayer;

  public
    constructor Create(Layer: TBaseLayer);

    procedure Render(Target: TBitmap32); virtual; abstract;
    property Progress: Real read FProgress write FProgress;
    property Layer: TBaseLayer read FLayer;
  end;

implementation

uses
  WD.Registry;

{ TBaseLayer }

class constructor TBaseLayer.Create;
begin

end;

constructor TBaseLayer.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FAnimations := TAnimationList.Create(True);
end;

destructor TBaseLayer.Destroy;
begin
  FAnimations.Free;

  inherited Destroy;
end;

procedure TBaseLayer.EnterLayer;
begin
  FIsLayerActive := True;
end;

procedure TBaseLayer.ExitLayer;
begin
  if not IsLayerActive then
    Exit;

  FIsLayerActive := False;
  if Assigned(FOnExitLayer) then
    FOnExitLayer(Self);
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

function TBaseLayer.HasTargetWindow(out WindowHandle: HWND): Boolean;
var
  Window: TWindow;
begin
  Result := HasTargetWindow(Window);
  if Result then
    WindowHandle := Window.Handle;
end;

// Sagt aus, ob es ein aktuelles Zielfenster gibt
//
// Was tatsächlich ein Zielfenster ist, liegt am verwendeten Implementierer des IWindowsHandler
function TBaseLayer.HasTargetWindow(out Window: TWindow): Boolean;
begin
  Result := WindowsHandler.GetWindowList(wldDominaTargets).HasFirst(Window);
end;

procedure TBaseLayer.AddAnimation(Animation: TAnimationBase; Duration, AnimationID: Integer);
begin
  FAnimations.Add(Animation);

  Take(Animation)
    .EachAnimation(Duration,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        TAnimationBase(O).Progress := AQ.CurrentInterval.Progress;
        InvalidateMainContent;
        Result := True;
      end,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        AQ.Remove(O);
        FAnimations.Remove(TAnimationBase(O));
        InvalidateMainContent;
        Result := True;
      end, AnimationID);
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
function TBaseLayer.HasMainContent: Boolean;
begin
  Result := False;
end;

// Zeichnet den Hauptinhalt
procedure TBaseLayer.RenderMainContent(Target: TBitmap32);
var
  Animation: TAnimationBase;
begin
  if FAnimations.Count > 0 then
  begin
    for Animation in FAnimations do
      Animation.Render(Target);
  end;
end;

procedure TBaseLayer.DoMainContentChanged;
begin
  if Assigned(FOnMainContentChanged) then
    FOnMainContentChanged(Self);
end;

// Erklärt das Layer für ungültig und erzwingt es sich zu aktualisieren
procedure TBaseLayer.Invalidate;
begin

end;

// In den abgeleiteten Klassen sollte der inherited-Aufruf dieser Methode am Ende der abgeleiteten
// Prozedur erfolgen.
procedure TBaseLayer.InvalidateMainContent;
begin
  // Diese Vorbedingung spart sehr viel Energie ein!
  // Denn sie sorgt dafür, dass man sie aus den abgeleiteten Layern so oft aufrufen kann wie man
  // will und sie triggert dennoch nur im vordefinierten Intervall.
  if FInvalidateMainContentLock then
    Exit;

  FInvalidateMainContentLock := True;

  Take(Self)
    .EachDelay(5,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        FInvalidateMainContentLock := False;
        DoMainContentChanged;
        Result := True;
      end);
end;

// Teilt dem Layer mit, dass sich das Zielfenster verändert hat
//
// Wird nur getriggert wenn GetRequiredWindowTrackings den Wert wtTargetChanged enthält.
procedure TBaseLayer.TargetWindowChanged;
begin

end;

// Teilt dem Layer mit, dass das Zielfenster bewegt oder in der Größe verändert wurde
//
// Wird nur getriggert wenn GetRequiredWindowTrackings den Wert wtTargetMoved enthält.
procedure TBaseLayer.TargetWindowMoved;
begin

end;

// Teilt dem Layer mit, dass ein Wechselzielfenster bewegt oder in der Größe verändert wurde
//
// HINWEIS: Nicht implementiert!
// Theoretisch sah es danach aus, also ob es benötigt wird. Noch gab es aber keinen praktischen
// Bedarf. Diese Methode wird noch nirgends aufgerufen.
//
// Wird nur getriggert wenn GetRequiredWindowTrackings den Wert wtAnySwitchTargetMoved enthält.
procedure TBaseLayer.SwitchTargetWindowMoved(WindowHandle: HWND);
begin
  raise ENotImplemented.Create('Diese Methode ist noch ein rein theoretisches Konstrukt');
end;

// Liefert die Anzahl der Millisekunden nach denen das Event TargetWindowChanged getriggert werden
// soll. Bei 0 wird sofort getriggert.
function TBaseLayer.GetTargetWindowChangedDelay: Integer;
begin
  Result := 0;
end;

// Liefert die Anzahl der Millisekunden nach denen das Event TargetWindowMoved getriggert werden
// soll. Bei 0 wird sofort getriggert.
function TBaseLayer.GetTargetWindowMovedDelay: Integer;
begin
  Result := 0;
end;

// Teilt mit, welche Tracking-Features von dem Layer erwünscht sind
function TBaseLayer.GetRequiredWindowTrackings: TWindowTrackings;
begin
  Result := [wtTargetChanged, wtTargetMoved];
end;


// Liefert den Anzeigenamen des Layers, der auch dem Benutzer präsentiert werden kann
function TBaseLayer.GetDisplayName: string;
begin
  Result := Copy(ClassName, 2, Pos('Layer', ClassName) - 2);
end;

function TBaseLayer.GetPrevLayer: TBaseLayer;
begin
  if Assigned(FOnGetPrevLayer) then
    Result := FOnGetPrevLayer
  else
    Result := nil;
end;

{ TAnimationBase }

constructor TAnimationBase.Create(Layer: TBaseLayer);
begin
  FLayer := Layer;
end;

end.
