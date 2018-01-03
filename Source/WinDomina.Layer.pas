unit WinDomina.Layer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  WinDomina.Types;

type
  TBaseLayer = class
  private

  protected
    FIsLayerActive: Boolean;

    procedure RegisterLayerActivationKeys(Keys: array of Integer);

  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure EnterLayer; virtual;
    procedure ExitLayer; virtual;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); virtual;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); virtual;

    property IsLayerActive: Boolean read FIsLayerActive;
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

end.
