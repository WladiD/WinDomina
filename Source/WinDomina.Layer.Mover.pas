unit WinDomina.Layer.Mover;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  WinDomina.Layer;

type
  TMoverLayer = class(TBaseLayer)
  public
    constructor Create; override;
  end;

implementation

{ TMoverLayer }

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkLeft, vkRight, vkUp, vkDown]);
end;

end.
