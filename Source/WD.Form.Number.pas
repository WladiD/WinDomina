unit WD.Form.Number;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Skia,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Skia,

  WD.KeyTools,
  WD.Registry,
  WD.WindowTools;

type
  TNumberForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FAssignedToWindow: HWND;
    FNumber: Byte;

    procedure UpdateContent;
    procedure SetNumber(Value: Byte);

  public
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;

    property AssignedToWindow: HWND read FAssignedToWindow write FAssignedToWindow;
    property Number: Byte read FNumber write SetNumber;
    property WindowHandle;
  end;

implementation

{$R *.dfm}

{ TNumberForm }

procedure TNumberForm.FormCreate(Sender: TObject);
var
  ExStyle: DWORD;
begin
  ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
  if (ExStyle and WS_EX_LAYERED) = 0 then
    SetWindowLong(Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);
end;

procedure TNumberForm.FormResize(Sender: TObject);
begin
  UpdateContent;
end;

procedure TNumberForm.FormShow(Sender: TObject);
begin
  UpdateContent;
end;

procedure TNumberForm.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  if HandleAllocated then
    inherited SetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TNumberForm.SetNumber(Value: Byte);
begin
  FNumber := Value;
  UpdateContent;
end;

procedure TNumberForm.UpdateContent;
var
  Info: TUpdateLayeredWindowInfo;
  SourcePosition: TPoint;
  Blend: TBlendFunction;
  Size: TSize;
  WindowPosition: TPoint;
  LBitmap: TBitmap;
begin
  if not Visible then
    Exit;

  Size.cx := Width;
  Size.cy := Height;
  
  if (Size.cx <= 0) or (Size.cy <= 0) then
    Exit;

  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(Size.cx, Size.cy);
    LBitmap.PixelFormat := pf32bit;
    // Skia auf GDI Canvas zeichnen
    LBitmap.SkiaDraw(
      procedure(const Canvas: ISkCanvas)
      begin
        Canvas.Clear(TAlphaColors.Null);
        KeyRenderManager.RenderSkia(Canvas, Number + vk0, TRectF.Create(0, 0, Size.cx, Size.cy), ksFlat);
      end);

    SourcePosition := Point(0, 0);
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := 255;
    Blend.AlphaFormat := AC_SRC_ALPHA;

    ZeroMemory(@Info, SizeOf(Info));
    WindowPosition := BoundsRect.Location;

    Info.cbSize := SizeOf(TUpdateLayeredWindowInfo);
    Info.pptSrc := @SourcePosition;
    Info.pptDst := @WindowPosition;
    Info.psize  := @Size;
    Info.pblend := @Blend;
    Info.dwFlags := ULW_ALPHA;
    Info.hdcSrc := LBitmap.Canvas.Handle;

    if not UpdateLayeredWindowIndirect(WindowHandle, @Info) then
      RaiseLastOSError();
  finally
    LBitmap.Free;
  end;
end;

end.
