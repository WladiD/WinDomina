// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.KeyDecorators;

interface

uses

  System.Classes,
  System.Diagnostics,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Skia,
  Vcl.Graphics,

  WD.KeyTools,
  WD.Types;

type

  TKeyDecorators = class
  public
    class procedure TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkBottomIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkLeftIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkRightIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkTopIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);

    class procedure TargetEdgeGrowBottomIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowLeftIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowRightIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeGrowTopIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkBottomIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkLeftIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkRightIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
    class procedure TargetEdgeShrinkTopIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
  end;

implementation

type

  TKeyDecoratorRenderer = class
  private
  type
    TTargetEdgeConfig = record
      BigIndent  : Single;
      EdgeWidth  : Single;
      SmallIndent: Single;
    end;

  var
    KeyRect : TRectF;
    Renderer: TKeyRenderer;
    Canvas  : ISkCanvas;

    procedure DrawRectEdge(Rect: TRectF; Edges: TRectEdges; EdgeWidth: Single; Color: TAlphaColor);
    function  GetTargetEdgeConfig(Edge: TRectEdge): TTargetEdgeConfig;
    procedure DrawTargetEdgeGrowIndicator(Edge: TRectEdge);
    procedure DrawTargetEdgeShrinkIndicator(Edge: TRectEdge);
  public
    constructor Create(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
  end;

constructor TKeyDecoratorRenderer.Create(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin
  Self.Renderer := Renderer;
  Self.Canvas := Canvas;
  Self.KeyRect := KeyRect
end;

procedure TKeyDecoratorRenderer.DrawRectEdge(Rect: TRectF; Edges: TRectEdges; EdgeWidth: Single; Color: TAlphaColor);
var
  Paint: ISkPaint;
begin
  Paint := TSkPaint.Create;
  Paint.Color := Color;
  Paint.Style := TSkPaintStyle.Fill;

  if reTop in Edges then
    Canvas.DrawRect(TRectF.Create(Rect.Left, Rect.Top, Rect.Right, Rect.Top + EdgeWidth), Paint);

  if reRight in Edges then
    Canvas.DrawRect(TRectF.Create(Rect.Right - EdgeWidth, Rect.Top, Rect.Right, Rect.Bottom), Paint);

  if reBottom in Edges then
    Canvas.DrawRect(TRectF.Create(Rect.Left, Rect.Bottom - EdgeWidth, Rect.Right, Rect.Bottom), Paint);

  if reLeft in Edges then
    Canvas.DrawRect(TRectF.Create(Rect.Left, Rect.Top, Rect.Left + EdgeWidth, Rect.Bottom), Paint);
end;

function TKeyDecoratorRenderer.GetTargetEdgeConfig(Edge: TRectEdge): TTargetEdgeConfig;
begin
  Result := Default(TTargetEdgeConfig);

  case Edge of
    reTop,
    reBottom:
    begin
      Result.BigIndent := KeyRect.Height * 0.25;
      Result.SmallIndent := KeyRect.Height * 0.1;
      Result.EdgeWidth := KeyRect.Height * 0.05;
    end;
    reRight,
    reLeft:
    begin
      Result.BigIndent := KeyRect.Width * 0.25;
      Result.SmallIndent := KeyRect.Width * 0.1;
      Result.EdgeWidth := KeyRect.Width * 0.05;
    end;
  end;
end;

procedure TKeyDecoratorRenderer.DrawTargetEdgeGrowIndicator(Edge: TRectEdge);
var
  Conf         : TTargetEdgeConfig;
  OppositeEdge : TRectEdge;
  TargetSymRect: TRectF;
  WinSymEdges  : TRectEdges;
  WinSymRect   : TRectF;
  Paint        : ISkPaint;
begin
  Conf := GetTargetEdgeConfig(Edge);

  OppositeEdge := GetOppositeEdge(Edge);
  WinSymRect := TRectF.Create(GetRectEdgeRect(Rect(Round(KeyRect.Left), Round(KeyRect.Top), Round(KeyRect.Right), Round(KeyRect.Bottom)), OppositeEdge, Round(Conf.SmallIndent)));
  WinSymEdges := [reTop, reRight, reBottom, reLeft];
  Exclude(WinSymEdges, OppositeEdge);

  TargetSymRect := TRectF.Create(GetRectEdgeRect(Rect(Round(KeyRect.Left), Round(KeyRect.Top), Round(KeyRect.Right), Round(KeyRect.Bottom)), Edge, Round(Conf.BigIndent)));
  TargetSymRect.Inflate(-Conf.SmallIndent, -Conf.SmallIndent);

  case Edge of
    reTop,
    reBottom:
      WinSymRect.Inflate(-Conf.BigIndent, 0);
    reRight,
    reLeft:
      WinSymRect.Inflate(0, -Conf.BigIndent);
  end;

  Paint := TSkPaint.Create;
  Paint.Color := TAlphaColors.Gray;
  Canvas.DrawRect(TargetSymRect, Paint);
  
  DrawRectEdge(WinSymRect, WinSymEdges, Conf.EdgeWidth, TAlphaColors.Lightgray);
end;

procedure TKeyDecoratorRenderer.DrawTargetEdgeShrinkIndicator(Edge: TRectEdge);
var
  Conf         : TTargetEdgeConfig;
  TargetSymRect: TRectF;
  WinSymEdges  : TRectEdges;
  WinSymRect   : TRectF;
  Paint        : ISkPaint;
begin
  Conf := GetTargetEdgeConfig(Edge);

  WinSymRect := TRectF.Create(GetRectEdgeRect(Rect(Round(KeyRect.Left), Round(KeyRect.Top), Round(KeyRect.Right), Round(KeyRect.Bottom)), Edge, Round(Conf.SmallIndent)));
  WinSymEdges := [reTop, reRight, reBottom, reLeft];
  Exclude(WinSymEdges, Edge);

  TargetSymRect := TRectF.Create(GetRectEdgeRect(Rect(Round(KeyRect.Left), Round(KeyRect.Top), Round(KeyRect.Right), Round(KeyRect.Bottom)), GetOppositeEdge(Edge), Round(Conf.BigIndent)));
  TargetSymRect.Inflate(-Conf.SmallIndent, -Conf.SmallIndent);

  case Edge of
    reTop,
    reBottom:
      WinSymRect.Inflate(-Conf.BigIndent, 0);
    reRight,
    reLeft:
      WinSymRect.Inflate(0, -Conf.BigIndent);
  end;

  Paint := TSkPaint.Create;
  Paint.Color := TAlphaColors.Gray;
  Canvas.DrawRect(TargetSymRect, Paint);
  
  DrawRectEdge(WinSymRect, WinSymEdges, Conf.EdgeWidth, TAlphaColors.Lightgray);
end;

{ TKeyDecorators }

class procedure TKeyDecorators.TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reBottom);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reLeft);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reRight);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeGrowIndicator(reTop);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkTopIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reTop);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkRightIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reRight);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkBottomIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reBottom);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkLeftIndicator(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Canvas, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reLeft);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeGrowBottomIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeGrowBottomIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeGrowLeftIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeGrowLeftIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeGrowRightIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeGrowRightIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeGrowTopIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeGrowTopIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeShrinkBottomIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeShrinkBottomIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeShrinkLeftIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeShrinkLeftIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeShrinkRightIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeShrinkRightIndicator(Renderer, Canvas, KeyRect); end;

class procedure TKeyDecorators.TargetEdgeShrinkTopIndicatorSkia(Renderer: TKeyRenderer; Canvas: ISkCanvas; KeyRect: TRectF);
begin TargetEdgeShrinkTopIndicator(Renderer, Canvas, KeyRect); end;

end.
