unit WD.KeyTools;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Defaults,
  System.Generics.Collections,
  System.UITypes,
  System.Diagnostics,
  System.Types,
  System.Math,
  System.Skia,
  Vcl.Graphics,

  AnyiQuack,
  Localization,
  WD.Types,
  WDDT.DelayedMethod;

type
  TKeyRenderer = class;
  TKeyDecoratorSkiaProc = reference to procedure(Renderer: TKeyRenderer; Canvas: ISkCanvas;
    KeyRect: TRectF);

  TKeyState = (ksFlat, ksUp, ksPressed);
  TRenderKey = record
    VirtualKey: Integer;
    State: TKeyState;
    Enabled: Boolean;
    Width: Integer;
    Height: Integer;
    DecoratorSkia: TKeyDecoratorSkiaProc;
    BackgroundColor: TAlphaColor;
    BackgroundAlpha: Single;
    FontSizeRatio: Single;
  end;

  TKeyRenderer = class
  public
    procedure RenderSkia(const Key: TRenderKey; Canvas: ISkCanvas; KeyRect: TRectF); virtual;
  end;

  TKeyRendererClass = class of TKeyRenderer;

  TKeyRenderManager = class(TComponent)
  private
    var
    FKeyRenderer: TKeyRenderer;
    FKeyRendererClass: TKeyRendererClass;

    procedure SetKeyRendererClass(Value: TKeyRendererClass);

  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure RenderSkia(Canvas: ISkCanvas; VirtualKey: Integer; Rect: TRectF; State: TKeyState;
      Enabled: Boolean = True; const Decorator: TKeyDecoratorSkiaProc = nil;
      BackgroundColor: TAlphaColor = TAlphaColors.White; BackgroundAlpha: Single = 0.7;
      FontSizeRatio: Single = 0.6);

    property KeyRendererClass: TKeyRendererClass read FKeyRendererClass write SetKeyRendererClass;
  end;

implementation

uses
  WD.Registry;

{ TKeyRenderManager }

class constructor TKeyRenderManager.Create;
begin

end;

constructor TKeyRenderManager.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  KeyRendererClass := TKeyRenderer;
end;

destructor TKeyRenderManager.Destroy;
begin
  FKeyRenderer.Free;

  inherited Destroy;
end;

procedure TKeyRenderManager.RenderSkia(Canvas: ISkCanvas; VirtualKey: Integer; Rect: TRectF;
  State: TKeyState; Enabled: Boolean; const Decorator: TKeyDecoratorSkiaProc;
  BackgroundColor: TAlphaColor; BackgroundAlpha: Single; FontSizeRatio: Single);
var
  RK: TRenderKey;
begin
  RK := Default(TRenderKey);
  RK.VirtualKey := VirtualKey;
  RK.State := State;
  RK.Enabled := Enabled;
  RK.Width := Round(Rect.Width);
  RK.Height := Round(Rect.Height);
  RK.DecoratorSkia := Decorator;
  RK.BackgroundColor := BackgroundColor;
  RK.BackgroundAlpha := BackgroundAlpha;
  RK.FontSizeRatio := FontSizeRatio;

  FKeyRenderer.RenderSkia(RK, Canvas, Rect);
end;

procedure TKeyRenderManager.SetKeyRendererClass(Value: TKeyRendererClass);
begin
  if Value <> FKeyRendererClass then
  begin
    FKeyRendererClass := Value;
    FKeyRenderer.Free;
    FKeyRenderer := FKeyRendererClass.Create;
  end;
end;

{ TKeyRenderer }

procedure TKeyRenderer.RenderSkia(const Key: TRenderKey; Canvas: ISkCanvas; KeyRect: TRectF);

  function GetKeyText: string;
  begin
    case Key.VirtualKey of
      vkNumpad0..vkNumpad9:
        Result := IntToStr(Key.VirtualKey - vkNumpad0);
      vk0..vk9:
        Result := IntToStr(Key.VirtualKey - vk0);
      vkA..vkZ:
        Result := string(AnsiChar(Key.VirtualKey));
      vkEscape:
        Result := Lang.Consts['KeyEscapeShort'];
    else
      Result := '';
    end;
  end;

var
  Paint: ISkPaint;
  Font: ISkFont;
  KeyText: string;
  TextBounds: TRectF;
  ArrowPath: ISkPath;
  ArrowIndent: Single;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  
  // Background
  Paint.Color := TAlphaColors.White;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 4;
  Canvas.DrawRect(KeyRect, Paint);

  Paint.Color := TAlphaColors.Black;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 2;
  Canvas.DrawRect(KeyRect, Paint);
  
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := Key.BackgroundColor;
  Paint.AlphaF := Key.BackgroundAlpha;
  var R := KeyRect;
  R.Inflate(-1, -1);
  Canvas.DrawRect(R, Paint);

  KeyText := GetKeyText;
  if KeyText <> '' then
  begin
    Font := TSkFont.Create(TSkTypeface.MakeDefault, KeyRect.Height * Key.FontSizeRatio);
    Font.MeasureText(KeyText, TextBounds);
    
    Paint.AlphaF := 1.0;

    // Text outline
    Paint.Color := TAlphaColors.White;
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 4;
    Canvas.DrawSimpleText(KeyText,
      KeyRect.Left + (KeyRect.Width - TextBounds.Width) / 2 - TextBounds.Left,
      KeyRect.Top + (KeyRect.Height - TextBounds.Height) / 2 - TextBounds.Top,
      Font, Paint);

    // Text fill
    Paint.Color := TAlphaColors.Black;
    Paint.Style := TSkPaintStyle.Fill;
    Canvas.DrawSimpleText(KeyText, 
      KeyRect.Left + (KeyRect.Width - TextBounds.Width) / 2 - TextBounds.Left,
      KeyRect.Top + (KeyRect.Height - TextBounds.Height) / 2 - TextBounds.Top,
      Font, Paint);
  end
  else if Key.VirtualKey in [vkLeft, vkRight, vkUp, vkDown] then
  begin
    ArrowIndent := KeyRect.Width * 0.25;
    var LPathBuilder: ISkPathBuilder := TSkPathBuilder.Create;
    
    case Key.VirtualKey of
      vkLeft:
      begin
        LPathBuilder.MoveTo(KeyRect.Left + ArrowIndent, KeyRect.Top + (KeyRect.Height / 2));
        LPathBuilder.LineTo(KeyRect.Right - ArrowIndent, KeyRect.Top + ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Right - ArrowIndent, KeyRect.Bottom - ArrowIndent);
        LPathBuilder.Close;
      end;
      vkRight:
      begin
        LPathBuilder.MoveTo(KeyRect.Left + ArrowIndent, KeyRect.Top + ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Right - ArrowIndent, KeyRect.Top + (KeyRect.Height / 2));
        LPathBuilder.LineTo(KeyRect.Left + ArrowIndent, KeyRect.Bottom - ArrowIndent);
        LPathBuilder.Close;
      end;
      vkUp:
      begin
        LPathBuilder.MoveTo(KeyRect.Left + (KeyRect.Width / 2), KeyRect.Top + ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Right - ArrowIndent, KeyRect.Bottom - ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Left + ArrowIndent, KeyRect.Bottom - ArrowIndent);
        LPathBuilder.Close;
      end;
      vkDown:
      begin
        LPathBuilder.MoveTo(KeyRect.Left + ArrowIndent, KeyRect.Top + ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Right - ArrowIndent, KeyRect.Top + ArrowIndent);
        LPathBuilder.LineTo(KeyRect.Left + (KeyRect.Width / 2), KeyRect.Bottom - ArrowIndent);
        LPathBuilder.Close;
      end;
    end;
    ArrowPath := LPathBuilder.Detach;
    
    Paint.AlphaF := 1.0;

    // Arrow outline
    Paint.Color := TAlphaColors.White;
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 4;
    Canvas.DrawPath(ArrowPath, Paint);

    // Arrow fill
    Paint.Color := TAlphaColors.Black;
    Paint.Style := TSkPaintStyle.Fill;
    Canvas.DrawPath(ArrowPath, Paint);
  end;

  if Assigned(Key.DecoratorSkia) then
    Key.DecoratorSkia(Self, Canvas, KeyRect);
end;

end.
