unit WD.KeyDecorators;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Diagnostics,
  System.Types,
  Vcl.Graphics,

  GR32,
  GR32_Polygons,

  WD.KeyTools,
  WD.Types;

type
  TKeyDecorators = class
  public
    class procedure TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
      KeyRect: TRect);
    class procedure TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
      KeyRect: TRect);
    class procedure TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
      KeyRect: TRect);
    class procedure TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
      KeyRect: TRect);
  end;

implementation

type
  TKeyDecoratorRenderer = class
  private
    Renderer: TKeyRenderer;
    Target: TBitmap32;
    KeyRect: TRect;

    procedure DrawRectEdge(Rect: TRect; Edges: TRectEdges; EdgeWidth: Integer; Color: TColor32);
    procedure DrawTargetEdgeGrowIndicator(Edge: TRectEdge);

  public
    constructor Create(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
  end;

constructor TKeyDecoratorRenderer.Create(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
begin
  Self.Renderer := Renderer;
  Self.Target := Target;
  Self.KeyRect := KeyRect
end;

procedure TKeyDecoratorRenderer.DrawRectEdge(Rect: TRect; Edges: TRectEdges; EdgeWidth: Integer;
  Color: TColor32);
begin
  if reTop in Edges then
    Target.FillRect(Rect.Left, Rect.Top, Rect.Right, Rect.Top + EdgeWidth, Color);

  if reRight in Edges then
    Target.FillRect(Rect.Right - EdgeWidth, Rect.Top, Rect.Right, Rect.Bottom, Color);

  if reBottom in Edges then
    Target.FillRect(Rect.Left, Rect.Bottom - EdgeWidth, Rect.Right, Rect.Bottom, Color);

  if reLeft in Edges then
    Target.FillRect(Rect.Left, Rect.Top, Rect.Left + EdgeWidth, Rect.Bottom, Color);
end;

procedure TKeyDecoratorRenderer.DrawTargetEdgeGrowIndicator(Edge: TRectEdge);
var
  SmallIndent, BigIndent, EdgeWidth: Integer;
  WinSymRect: TRect;
  WinSymEdges: TRectEdges;
  OppositeEdge: TRectEdge;
begin
  case Edge of
    reTop,
    reBottom:
    begin
      BigIndent := Round(KeyRect.Height * 0.25);
      SmallIndent := Round(KeyRect.Height * 0.1);
      EdgeWidth := Round(KeyRect.Height * 0.05);
    end;
    reRight,
    reLeft:
    begin
      BigIndent := Round(KeyRect.Width * 0.25);
      SmallIndent := Round(KeyRect.Width * 0.1);
      EdgeWidth := Round(KeyRect.Width * 0.05);
    end;
  else
    Exit;
  end;

  OppositeEdge := GetOppositeEdge(Edge);
  WinSymRect := GetRectEdgeRect(KeyRect, OppositeEdge, SmallIndent);
  WinSymEdges := [reTop, reRight, reBottom, reLeft];
  Exclude(WinSymEdges, OppositeEdge);

  case Edge of
    reTop:
    begin
      Target.FillRect(
        KeyRect.Left + SmallIndent, KeyRect.Top + SmallIndent,
        KeyRect.Right - SmallIndent, KeyRect.Top + SmallIndent + EdgeWidth, clGray32);
      WinSymRect.Inflate(-BigIndent, 0, -BigIndent, 0);
    end;
    reRight:
    begin
      Target.FillRect(
        KeyRect.Right - SmallIndent - EdgeWidth, KeyRect.Top + SmallIndent,
        KeyRect.Right - SmallIndent, KeyRect.Bottom - SmallIndent, clGray32);
      WinSymRect.Inflate(0, -BigIndent, 0, -BigIndent);
    end;
    reBottom:
    begin
      Target.FillRect(
        KeyRect.Left + SmallIndent, KeyRect.Bottom - SmallIndent - EdgeWidth,
        KeyRect.Right - SmallIndent, KeyRect.Bottom - SmallIndent, clGray32);
      WinSymRect.Inflate(-BigIndent, 0, -BigIndent, 0);
    end;
    reLeft:
    begin
      Target.FillRect(
        KeyRect.Left + SmallIndent, KeyRect.Top + SmallIndent,
        KeyRect.Left + SmallIndent + EdgeWidth, KeyRect.Bottom - SmallIndent, clGray32);
      WinSymRect.Inflate(0, -BigIndent, 0, -BigIndent);
    end;
  else
    Exit;
  end;

  DrawRectEdge(WinSymRect, WinSymEdges, EdgeWidth, clLightGray32);
end;

{ TKeyDecorators }

class procedure TKeyDecorators.TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
  KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reBottom);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
  KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reLeft);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
  KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reRight);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32;
  KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reTop);
  finally
    KDR.Free;
  end;
end;

end.
