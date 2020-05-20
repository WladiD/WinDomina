unit WD.Layer.KeyViewer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Generics.Collections,
  System.Contnrs,
  System.Math,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Controls,

  GR32,
  GR32_Polygons,
  GR32_VectorUtils,
  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,
  AQPControlAnimations,
  SendInputHelper,

  WD.Types,
  WD.Layer,
  WD.Registry,
  WD.WindowTools,
  WD.WindowMatchSnap,
  WD.Form.Number,
  WD.KeyTools,
  WD.KeyDecorators;

type
  TKeyViewerLayer = class(TBaseLayer)
  private
  public
    constructor Create; override;

    function HasMainContent: Boolean; override;
    procedure RenderMainContent(Target: TBitmap32); override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;

  end;

implementation

{ TKeyViewerLayer }

constructor TKeyViewerLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkF1]);
end;

procedure TKeyViewerLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);
begin
  if Key = vkEscape then
  begin

    ExitLayer;

  end;

  // Catch all keys, the only way to escape is [Esc]
  Handled := True;
end;

function TKeyViewerLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

procedure TKeyViewerLayer.RenderMainContent(Target: TBitmap32);
begin
  inherited RenderMainContent(Target);

  Target.Font.Size := 20;

  Target.RenderText(10, 10, '!!!KeyViewer!!!', 0, clBlack32);
end;

end.
