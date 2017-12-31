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
    procedure EnterLayer; virtual; abstract;
    procedure ExitLayer; virtual; abstract;
  end;

implementation

{ TBaseLayer }

// Registriert die Tasten, die zu einer Aktivierung des Layers f�hren
//
// Es ist irrelevant welcher Layer gerade aktiv ist, wenn die jeweilige Taste nicht vom aktiven
// Layer kosumiert wurde, wird sie f�r die Aktivierung verwendet.
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
