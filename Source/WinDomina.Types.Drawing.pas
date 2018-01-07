unit WinDomina.Types.Drawing;

interface

uses
  System.SysUtils,
  Winapi.D2D1,
  Winapi.Wincodec;

type
  IDrawContext = interface
    ['{A7C5D212-3C5F-42AC-BA9D-F372346F8560}']

    function D2DFactory: ID2D1Factory;
    function WICFactory: IWICImagingFactory;
    function RenderTarget: ID2D1RenderTarget;
  end;

implementation

end.
