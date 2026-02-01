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
  Vcl.Graphics,

  GR32,
  GR32_Polygons,

  WD.KeyTools,
  WD.Types;

type

  TKeyDecorators = class
  public
    class procedure TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeShrinkBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeShrinkLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeShrinkRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
    class procedure TargetEdgeShrinkTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
  end;

implementation

type

  TKeyDecoratorRenderer = class
  private
  type
    TTargetEdgeConfig = record
      BigIndent  : Integer;
      EdgeWidth  : Integer;
      SmallIndent: Integer;
    end;

  var
    KeyRect : TRect;
    Renderer: TKeyRenderer;
    Target  : TBitmap32;

    procedure DrawRectEdge(Rect: TRect; Edges: TRectEdges; EdgeWidth: Integer; Color: TColor32);
    function  GetTargetEdgeConfig(Edge: TRectEdge): TTargetEdgeConfig;
    procedure DrawTargetEdgeGrowIndicator(Edge: TRectEdge);
    procedure DrawTargetEdgeShrinkIndicator(Edge: TRectEdge);
  public
    constructor Create(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
  end;

constructor TKeyDecoratorRenderer.Create(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
begin
  Self.Renderer := Renderer;
  Self.Target := Target;
  Self.KeyRect := KeyRect
end;

procedure TKeyDecoratorRenderer.DrawRectEdge(Rect: TRect; Edges: TRectEdges; EdgeWidth: Integer; Color: TColor32);
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

function TKeyDecoratorRenderer.GetTargetEdgeConfig(Edge: TRectEdge): TTargetEdgeConfig;
begin
  Result := Default(TTargetEdgeConfig);

  case Edge of
    reTop,
    reBottom:
    begin
      Result.BigIndent := Round(KeyRect.Height * 0.25);
      Result.SmallIndent := Round(KeyRect.Height * 0.1);
      Result.EdgeWidth := Round(KeyRect.Height * 0.05);
    end;
    reRight,
    reLeft:
    begin
      Result.BigIndent := Round(KeyRect.Width * 0.25);
      Result.SmallIndent := Round(KeyRect.Width * 0.1);
      Result.EdgeWidth := Round(KeyRect.Width * 0.05);
    end;
  end;
end;

procedure TKeyDecoratorRenderer.DrawTargetEdgeGrowIndicator(Edge: TRectEdge);
var
  Conf         : TTargetEdgeConfig;
  OppositeEdge : TRectEdge;
  TargetSymRect: TRect;
  WinSymEdges  : TRectEdges;
  WinSymRect   : TRect;
begin
  Conf := GetTargetEdgeConfig(Edge);

  OppositeEdge := GetOppositeEdge(Edge);
  WinSymRect := GetRectEdgeRect(KeyRect, OppositeEdge, Conf.SmallIndent);
  WinSymEdges := [reTop, reRight, reBottom, reLeft];
  Exclude(WinSymEdges, OppositeEdge);

  TargetSymRect := GetRectEdgeRect(KeyRect, Edge, Conf.BigIndent);
  TargetSymRect.Inflate(-Conf.SmallIndent, -Conf.SmallIndent);

  case Edge of
    reTop,
    reBottom:
      WinSymRect.Inflate(-Conf.BigIndent, 0, -Conf.BigIndent, 0);
    reRight,
    reLeft:
      WinSymRect.Inflate(0, -Conf.BigIndent, 0, -Conf.BigIndent);
  end;

  Target.FillRect(
    TargetSymRect.Left, TargetSymRect.Top,
    TargetSymRect.Right, TargetSymRect.Bottom, clGray32);
  DrawRectEdge(WinSymRect, WinSymEdges, Conf.EdgeWidth, clLightGray32);
end;

procedure TKeyDecoratorRenderer.DrawTargetEdgeShrinkIndicator(Edge: TRectEdge);
var
  Conf         : TTargetEdgeConfig;
  TargetSymRect: TRect;
  WinSymEdges  : TRectEdges;
  WinSymRect   : TRect;
begin
  Conf := GetTargetEdgeConfig(Edge);

  WinSymRect := GetRectEdgeRect(KeyRect, Edge, Conf.SmallIndent);
  WinSymEdges := [reTop, reRight, reBottom, reLeft];
  Exclude(WinSymEdges, Edge);

  TargetSymRect := GetRectEdgeRect(KeyRect, GetOppositeEdge(Edge), Conf.BigIndent);
  TargetSymRect.Inflate(-Conf.SmallIndent, -Conf.SmallIndent);

  case Edge of
    reTop,
    reBottom:
      WinSymRect.Inflate(-Conf.BigIndent, 0, -Conf.BigIndent, 0);
    reRight,
    reLeft:
      WinSymRect.Inflate(0, -Conf.BigIndent, 0, -Conf.BigIndent);
  end;

  Target.FillRect(
    TargetSymRect.Left, TargetSymRect.Top,
    TargetSymRect.Right, TargetSymRect.Bottom, clGray32);
  DrawRectEdge(WinSymRect, WinSymEdges, Conf.EdgeWidth, clLightGray32);
end;

{ TKeyDecorators }

class procedure TKeyDecorators.TargetEdgeGrowBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
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

class procedure TKeyDecorators.TargetEdgeGrowLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
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

class procedure TKeyDecorators.TargetEdgeGrowRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
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

class procedure TKeyDecorators.TargetEdgeGrowTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
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

class procedure TKeyDecorators.TargetEdgeShrinkTopIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reTop);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkRightIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reRight);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkBottomIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reBottom);
  finally
    KDR.Free;
  end;
end;

class procedure TKeyDecorators.TargetEdgeShrinkLeftIndicator(Renderer: TKeyRenderer; Target: TBitmap32; KeyRect: TRect);
var
  KDR: TKeyDecoratorRenderer;
begin
  KDR := TKeyDecoratorRenderer.Create(Renderer, Target, KeyRect);
  try
    KDR.DrawTargetEdgeShrinkIndicator(reLeft);
  finally
    KDR.Free;
  end;
end;

end.
