unit WinDomina.Layer.Grid;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  WinDomina.Layer;

type
  TGridLayer = class(TBaseLayer)
  public
    constructor Create; override;
  end;


implementation

{ TGridLayer }

constructor TGridLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkNumpad0, vkNumpad1, vkNumpad2, vkNumpad3, vkNumpad4, vkNumpad5,
    vkNumpad6, vkNumpad7, vkNumpad8, vkNumpad9]);
end;

end.
