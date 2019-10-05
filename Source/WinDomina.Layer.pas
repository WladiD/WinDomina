unit WinDomina.Layer;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,

  GR32,
  AnyiQuack,
  WindowEnumerator,

  WinDomina.Types;

type
  TBaseLayer = class;
  TBaseLayerClass = class of TBaseLayer;
  TKeyLayerList = TDictionary<Integer, TBaseLayer>;
  TLayerList = TObjectList<TBaseLayer>;
  TLayerStack = TStack<TBaseLayer>;
  TAnimationBase = class;
  TAnimationList = TObjectList<TAnimationBase>;

  TBaseLayer = class
  private
    class var
    MainContentLoopTimerID: Integer;
    LayerInvalidateDelayID: Integer;
  private
    FOnMainContentChanged: TNotifyEvent;
    FAnimations: TAnimationList;

    procedure DoMainContentChanged;

  protected
    FIsLayerActive: Boolean;
    FMonitorHandler: IMonitorHandler;
    FWindowsHandler: IWindowsHandler;
    MainContentChanged: Boolean;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);

    function HasTargetWindow(out WindowHandle: HWND): Boolean; overload;
    function HasTargetWindow(out Window: TWindow): Boolean; overload;

    procedure AddAnimation(Animation: TAnimationBase; Duration, AnimationID: Integer);

  public
    class constructor Create;
    constructor Create; virtual;
    destructor Destroy; override;

    procedure EnterLayer; virtual;
    procedure ExitLayer; virtual;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); virtual;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); virtual;

    function HasMainContent: Boolean; virtual;
    procedure RenderMainContent(Target: TBitmap32); virtual;
    procedure InvalidateMainContent; virtual;

    procedure TargetWindowChanged; virtual;
    procedure TargetWindowMoved; virtual;

    function GetDisplayName: string; virtual;

    property IsLayerActive: Boolean read FIsLayerActive;
    property MonitorHandler: IMonitorHandler read FMonitorHandler write FMonitorHandler;
    property WindowsHandler: IWindowsHandler read FWindowsHandler write FWindowsHandler;
    // Dieses Ereignis wird ausgelöst, wenn der Layer selbst feststellt, dass er sich neu zeichnen
    // muss
    property OnMainContentChanged: TNotifyEvent read FOnMainContentChanged
      write FOnMainContentChanged;
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
  WinDomina.Registry;

{ TBaseLayer }

class constructor TBaseLayer.Create;
begin
  MainContentLoopTimerID := TAQ.GetUniqueID;
  LayerInvalidateDelayID := TAQ.GetUniqueID;
end;

constructor TBaseLayer.Create;
begin
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

// Teilt dem Layer mit, dass sich das Zielfenster verändert hat
procedure TBaseLayer.TargetWindowChanged;
begin

end;

// Teilt dem Layer mit, dass das Zielfenster bewegt oder in der Größe verändert wurde
procedure TBaseLayer.TargetWindowMoved;
begin

end;

// Liefert den Anzeigenamen des Layers, der auch dem Benutzer präsentiert werden kann
function TBaseLayer.GetDisplayName: string;
begin
  Result := Copy(ClassName, 2, Pos('Layer', ClassName) - 2);
end;

{ TAnimationBase }

constructor TAnimationBase.Create(Layer: TBaseLayer);
begin
  FLayer := Layer;
end;

end.
