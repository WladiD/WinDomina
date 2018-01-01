unit WinDomina.Layer;

interface

uses
  System.SysUtils,
  System.Classes;

type
  TBaseLayer = class
  protected
    procedure RegisterLayerActivationKeys(Keys: array of Integer);

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); virtual;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); virtual;

  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure EnterLayer; virtual; abstract;
    procedure ExitLayer; virtual; abstract;
  end;

implementation

{ TBaseLayer }

constructor TBaseLayer.Create;
begin

end;

destructor TBaseLayer.Destroy;
begin

  inherited Destroy;
end;

// Registriert die Tasten, die zu einer Aktivierung des Layers führen
//
// Es ist irrelevant welcher Layer gerade aktiv ist, wenn die jeweilige Taste nicht vom aktiven
// Layer kosumiert wurde, wird sie für die Aktivierung verwendet.
procedure TBaseLayer.RegisterLayerActivationKeys(Keys: array of Integer);
begin

end;

procedure TBaseLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);
begin

end;

procedure TBaseLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

end.
