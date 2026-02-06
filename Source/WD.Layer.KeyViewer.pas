// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.Layer.KeyViewer;

interface

uses

  Winapi.Windows,

  System.Classes,
  System.Contnrs,
  System.Diagnostics,
  System.Generics.Collections,
  System.Math,
  System.Skia,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,

  AnyiQuack,
  AQPControlAnimations,
  AQPSystemTypesAnimations,
  Localization,
  WindowEnumerator,

  WD.Form.Number,
  WD.KeyDecorators,
  WD.KeyTools,
  WD.LangIndex,
  WD.Layer,
  WD.Layer.Grid,
  WD.Layer.Mover,
  WD.Registry,
  WD.Types,
  WD.WindowMatchSnap,
  WD.WindowTools;

type

  THelpBaseItem = class;
  THelpSectionItem = class;
  THelpKeyAssignmentItem = class;

  TKeyViewerLayer = class(TBaseLayer)
  private
    class var
    InitAniID: Integer;
  private
    FActiveHelpSection: THelpSectionItem;
    FInitProgress     : Single;
    FSections         : TObjectList<THelpSectionItem>;

    function  AddLayerHelpSection(Layer: TBaseLayerClass): THelpSectionItem;
    function  HasActiveSectionByKey(Key: Integer; out Section: THelpSectionItem): Boolean;
    procedure SetActiveSection(Value: THelpSectionItem);
    procedure SetActiveSectionByLayer(Layer: TBaseLayer);
    procedure SetInitProgress(const Value: Single);

    property InitProgress: Single read FInitProgress write SetInitProgress;
    property ActiveHelpSection: THelpSectionItem read FActiveHelpSection write SetActiveSection;

  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure EnterLayer; override;
    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    function  HasMainContent: Boolean; override;
    function  HitTest(const Point: TPoint): Boolean; override;
    procedure RenderMainContentSkia(Canvas: ISkCanvas); override;
  end;

  THelpBaseItem = class
  private
    FLeft: Integer;
    FTop : Integer;

    function GetDescription: string;

  protected
    FAvailWidth    : Integer;
    FRequiredHeight: Integer;

    const
    TextStartXFactor = 0.25;
    KeySizeFactor    = 0.045;

  public
    ActivationKeyID     : Integer;
    DescriptionCustom   : String;
    DescriptionLangIndex: Integer;

    function  GetRequiredHeight(AvailWidth: Integer): Integer; virtual; abstract;
    procedure RenderSkia(Canvas: ISkCanvas); virtual; abstract;

    property Description: string read GetDescription;
    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
  end;

  THelpSectionItem = class(THelpBaseItem)
  private
    const
    KeyWidthFactor = 0.2;
    KeyPaddingLeftFactor = 0.05;
    KeyPaddingRightFactor = 0.05;
    KeyPaddingTopFactor = 0.05;
    KeyPaddingBottomFactor = 0.05;
    HeadlineFontSize = 20;
    HeadlinePaddingLeft = 0;
    HeadlinePaddingRight = 0;
    HeadlinePaddingTop = 5;
    HeadlinePaddingBottom = 0;

    var
    FKeys          : TObjectList<THelpKeyAssignmentItem>;
    FLayer         : TBaseLayerClass;

  public
    constructor Create(Layer: TBaseLayerClass);
    destructor  Destroy; override;

    procedure AddKeyAssignment(Key: THelpKeyAssignmentItem);
    function  GetRequiredHeight(AvailWidth: Integer): Integer; override;
    procedure RenderSkia(Canvas: ISkCanvas); override;
    procedure RenderContentSkia(Canvas: ISkCanvas; const Rect: TRectF);
  end;

  THelpKeyAssignmentItem = class(THelpBaseItem)
  private
    const
    KeyPaddingLeftFactor = 0.05;
    KeyPaddingRightFactor = 0.05;
    KeyPaddingTopFactor = 0.05;
    KeyPaddingBottomFactor = 0.05;
    HeadlineFontSize = 20;
    HeadlinePaddingLeft = 0;
    HeadlinePaddingRight = 0;
    HeadlinePaddingTop = 5;
    HeadlinePaddingBottom = 0;

    var
    FSection       : THelpSectionItem;

  protected
    function GetKeySizeRequired(AvailWidth: Integer): TSize; virtual;
    procedure RenderDescriptionSkia(Canvas: ISkCanvas; const Rect: TRectF; FontSize: Single);

  public
    Key  : Integer;
    Shift: TShiftState;

    function  GetRequiredHeight(AvailWidth: Integer): Integer; override;
    procedure RenderSkia(Canvas: ISkCanvas); override;
  end;

  THelpKeyAssignmentItemClass = class of THelpKeyAssignmentItem;

  THelp4ArrowKeysAssignmentItem = class(THelpKeyAssignmentItem)
  protected
    function GetKeySizeRequired(AvailWidth: Integer): TSize; override;
  public
    procedure RenderSkia(Canvas: ISkCanvas); override;
  end;

  THelpAllDigitKeysAssignmentItem = class(THelpKeyAssignmentItem)
  protected
    function GetKeySizeRequired(AvailWidth: Integer): TSize; override;
  public
    procedure RenderSkia(Canvas: ISkCanvas); override;
  end;

  THelpDigitAndDigitKeyAssignmentItem = class(THelpKeyAssignmentItem)
  protected
    function GetKeySizeRequired(AvailWidth: Integer): TSize; override;
  public
    procedure RenderSkia(Canvas: ISkCanvas); override;
  end;

implementation

{ TKeyViewerLayer }

class constructor TKeyViewerLayer.Create;
begin
  InitAniID := TAQ.GetUniqueID;
end;

constructor TKeyViewerLayer.Create(Owner: TComponent);
var
  Section: THelpSectionItem;

  function AddKeyAssignmentItem(KeyClass: THelpKeyAssignmentItemClass): THelpKeyAssignmentItem;
  begin
    Result := KeyClass.Create;
    Result.FSection := Section;
    Section.AddKeyAssignment(Result);
  end;

var
  Key: THelpKeyAssignmentItem;
begin
  inherited Create(Owner);

  RegisterLayerActivationKeys([vkF1]);
  FSections := TObjectList<THelpSectionItem>.Create;

  // All key assignments for the mover layer
  Section := AddLayerHelpSection(TMoverLayer);

  Key := AddKeyAssignmentItem(THelpAllDigitKeysAssignmentItem);
  Key.DescriptionLangIndex := LS_9;

  Key := AddKeyAssignmentItem(THelp4ArrowKeysAssignmentItem);
  Key.DescriptionLangIndex := LS_10;

  Key := AddKeyAssignmentItem(THelp4ArrowKeysAssignmentItem);
  Key.Shift := [ssCtrl];
  Key.DescriptionLangIndex := LS_11;

  Key := AddKeyAssignmentItem(THelp4ArrowKeysAssignmentItem);
  Key.Shift := [ssShift];
  Key.DescriptionLangIndex := LS_12;

  Key := AddKeyAssignmentItem(THelpKeyAssignmentItem);
  Key.Key := vkBack;
  Key.DescriptionLangIndex := LS_13;

  // All key assignments for the grid layer
  Section := AddLayerHelpSection(TGridLayer);

  Key := AddKeyAssignmentItem(THelpAllDigitKeysAssignmentItem);
  Key.DescriptionLangIndex := LS_14;

  Key := AddKeyAssignmentItem(THelpDigitAndDigitKeyAssignmentItem);
  Key.DescriptionLangIndex := LS_15;

  Key := AddKeyAssignmentItem(THelpKeyAssignmentItem);
  Key.Key := vkBack;
  Key.DescriptionLangIndex := LS_13;

  FExclusive := True;
end;

destructor TKeyViewerLayer.Destroy;
begin
  FSections.Free;
  inherited Destroy;
end;

procedure TKeyViewerLayer.EnterLayer;
begin
  inherited EnterLayer;

  FInitProgress := 0;
  SetActiveSectionByLayer(GetPrevLayer);

  Take(Self)
    .CancelAnimations(InitAniID)
    .EachAnimation(400,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        if O is TKeyViewerLayer then
          TKeyViewerLayer(O).InitProgress := TAQ.EaseReal(0, 1, AQ.CurrentInterval.Progress, etSinus);
        Result := True;
      end, nil, InitAniID);
end;

procedure TKeyViewerLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);
var
  Section: THelpSectionItem;
begin
  if Key = vkEscape then
    ExitLayer
  else if HasActiveSectionByKey(Key, Section) then
    ActiveHelpSection := Section;

  // Catch all keys, the only way to escape is [Esc]
  Handled := True;
end;

function TKeyViewerLayer.HasActiveSectionByKey(Key: Integer; out Section: THelpSectionItem): Boolean;
var
  CheckSection: THelpSectionItem;
begin
  for CheckSection in FSections do
    if CheckSection.ActivationKeyID = Key then
    begin
      Section := CheckSection;
      Exit(True);
    end;

  Result := False;
end;

function TKeyViewerLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

function TKeyViewerLayer.HitTest(const Point: TPoint): Boolean;
begin
  Result := False;
end;

procedure TKeyViewerLayer.RenderMainContentSkia(Canvas: ISkCanvas);
const
  IndentTop = 0.1;
  IndentLeft = 0.1;
  IndentRight = 0.1;
  IndentBottom = 0.05;

  function WidthFactor(Factor: Real): Single;
  begin
    Result := Canvas.GetLocalClipBounds.Width * Factor * InitProgress;
  end;

  function HeightFactor(Factor: Real): Single;
  begin
    Result := Canvas.GetLocalClipBounds.Height * Factor * InitProgress;
  end;

  function GetMaxRequiredSectionHeight(AvailWidth: Integer): Integer;
  var
    Section: THelpSectionItem;
    CheckHeight: Integer;
  begin
    Result := 0;
    for Section in FSections do
    begin
      CheckHeight := Section.GetRequiredHeight(AvailWidth);
      if CheckHeight > Result then
        Result := CheckHeight;
    end;
  end;

var
  EscKeyRectF             : TRectF;
  EscKeyWidth             : Single;
  Font                    : ISkFont;
  HeadlinePointF          : TPointF;
  HelpContentRectF        : TRectF;
  MaxRequiredSectionHeight: Integer;
  Paint                   : ISkPaint;
  Path                    : ISkPath;
  PathBuilder             : ISkPathBuilder;
  SectionsRectF           : TRectF;

  procedure RenderSections;
  var
    Section: THelpSectionItem;
    Y      : Single;
  begin
    Y := SectionsRectF.Top;
    for Section in FSections do
    begin
      Section.Left := Round(SectionsRectF.Left);
      Section.Top := Round(Y);
      Y := Y + MaxRequiredSectionHeight;
      Section.RenderSkia(Canvas);
    end;
  end;

  procedure RenderActiveSectionContent;
  begin
    if Assigned(ActiveHelpSection) then
      ActiveHelpSection.RenderContentSkia(Canvas, HelpContentRectF);
  end;

begin
  inherited RenderMainContentSkia(Canvas);

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.Black;
  Paint.Alpha := Round(240 * InitProgress);

  HelpContentRectF := TRectF.Create(
    WidthFactor(IndentLeft),
    HeightFactor(IndentTop),
    Canvas.GetLocalClipBounds.Width - WidthFactor(IndentRight),
    Canvas.GetLocalClipBounds.Height - HeightFactor(IndentBottom));

  // Background overlays (darkening)
  Canvas.DrawRect(TRectF.Create(
    0, 0,
    HelpContentRectF.Left, Canvas.GetLocalClipBounds.Height), Paint);
  Canvas.DrawRect(TRectF.Create(
    HelpContentRectF.Left, 0,
    HelpContentRectF.Right, HelpContentRectF.Top), Paint);
  Canvas.DrawRect(TRectF.Create(
    HelpContentRectF.Right, 0,
    Canvas.GetLocalClipBounds.Width, Canvas.GetLocalClipBounds.Height), Paint);
  Canvas.DrawRect(TRectF.Create(
    HelpContentRectF.Left, HelpContentRectF.Bottom,
    HelpContentRectF.Right, Canvas.GetLocalClipBounds.Height), Paint);

  SectionsRectF := HelpContentRectF;
  SectionsRectF.Right := SectionsRectF.Left + MonitorHandler.ConvertMmToPixel(80);
  HelpContentRectF.Left := SectionsRectF.Right;

  // Main help area background (white)
  Paint.Color := TAlphaColors.White;
  Paint.Alpha := Round(255 * InitProgress);
  Canvas.DrawRect(HelpContentRectF, Paint);

  // Sections area background (gray)
  Paint.Color := TAlphaColors.Lightgray;
  Canvas.DrawRect(SectionsRectF, Paint);

  // Headline
  Font := TSkFont.Create(TSkTypeface.MakeDefault, HeightFactor(0.05));
  HeadlinePointF := TPointF.Create(WidthFactor(IndentLeft), HeightFactor(0.04));

  Paint.Color := TAlphaColors.White;
  Paint.Alpha := 255;
  Canvas.DrawSimpleText(Lang[LS_16], HeadlinePointF.X, HeadlinePointF.Y + Font.Size, Font, Paint);

  EscKeyWidth := Abs(Font.Size);
  HeadlinePointF.X := HeadlinePointF.X - (10 + EscKeyWidth);

  EscKeyRectF := TRectF.Create(EscKeyWidth, HeadlinePointF.Y,
    EscKeyWidth * 2, HeadlinePointF.Y + EscKeyWidth);

  Paint.Color := TAlphaColors.White;
  Canvas.DrawRect(EscKeyRectF, Paint);
  KeyRenderManager.RenderSkia(Canvas, vkEscape, EscKeyRectF, ksFlat);

  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 3;
  Paint.Color := TAlphaColors.White;

  // Arrow to the left
  PathBuilder := TSkPathBuilder.Create;
  PathBuilder.MoveTo(EscKeyRectF.Left - 5, EscKeyRectF.Top);
  PathBuilder.LineTo(EscKeyRectF.Left - 15, EscKeyRectF.Top + EscKeyRectF.Height / 2);
  PathBuilder.LineTo(EscKeyRectF.Left - 5, EscKeyRectF.Bottom);
  Path := PathBuilder.Snapshot;
  Canvas.DrawPath(Path, Paint);

  MaxRequiredSectionHeight := GetMaxRequiredSectionHeight(Round(SectionsRectF.Width));
  RenderSections;
  RenderActiveSectionContent;
end;

procedure TKeyViewerLayer.SetActiveSection(Value: THelpSectionItem);
begin
  if FActiveHelpSection = Value then
    Exit;

  FActiveHelpSection := Value;
  InvalidateMainContent;
end;

procedure TKeyViewerLayer.SetActiveSectionByLayer(Layer: TBaseLayer);
var
  Section: THelpSectionItem;
begin
  if not Assigned(Layer) then
    Exit;

  for Section in FSections do
    if Section.FLayer = Layer.ClassType then
    begin
      ActiveHelpSection := Section;
      Exit;
    end;
end;

procedure TKeyViewerLayer.SetInitProgress(const Value: Single);
begin
  if not SameValue(Value, FInitProgress) then
  begin
    FInitProgress := Value;
    InvalidateMainContent;
  end;
end;

function TKeyViewerLayer.AddLayerHelpSection(Layer: TBaseLayerClass): THelpSectionItem;
var
  K         : Integer;
  NewSection: THelpSectionItem;
  TestPair  : TPair<Integer, TBaseLayer>;
begin
  NewSection := THelpSectionItem.Create(Layer);
  FSections.Add(NewSection);
  Result := NewSection;

  for TestPair in LayerActivationKeys.ToArray do
    if TestPair.Value.ClassType = Layer then
    begin
      K := TestPair.Key;
      NewSection.ActivationKeyID := K;
      NewSection.DescriptionCustom := TestPair.Value.GetDisplayName;
      Break;
    end;
end;

{ THelpBaseItem }

function THelpBaseItem.GetDescription: string;
begin
  if DescriptionCustom <> '' then
    Result := DescriptionCustom
  else
    Result := Lang[DescriptionLangIndex];
end;

{ THelpSectionItem }

constructor THelpSectionItem.Create(Layer: TBaseLayerClass);
begin
  FLayer := Layer;
  FKeys := TObjectList<THelpKeyAssignmentItem>.Create;
end;

destructor THelpSectionItem.Destroy;
begin
  FKeys.Free;

  inherited Destroy;
end;

function THelpSectionItem.GetRequiredHeight(AvailWidth: Integer): Integer;

  function CalcRequiredHeight: Integer;
  var
    KeyHeight: Integer;
    LBitmap  : TBitmap;
  begin
    LBitmap := TBitmap.Create;
    try
      LBitmap.Canvas.Font.Name := 'Arial';
      LBitmap.Canvas.Font.Size := HeadlineFontSize;

      KeyHeight := Round(AvailWidth * KeyWidthFactor);

      // Rough estimation of text height
      Result := LBitmap.Canvas.TextHeight(Description);
      if KeyHeight > Result then
        Result := KeyHeight;
    finally
      LBitmap.Free;
    end;
  end;

begin
  if FAvailWidth = AvailWidth then
    Result := FRequiredHeight
  else
  begin
    Result := CalcRequiredHeight;
    FAvailWidth := AvailWidth;
    FRequiredHeight := Result;
  end;
end;

procedure THelpSectionItem.RenderSkia(Canvas: ISkCanvas);
var
  Font      : ISkFont;
  KeyPadding: Single;
  KeyQSize  : Single;
  KeyRectF  : TRectF;
  Paint     : ISkPaint;
  Text      : String;
  TextBounds: TRectF;
  TextRectF : TRectF;
  WholeRectF: TRectF;
begin
  WholeRectF := TRectF.Create(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeyQSize := WholeRectF.Width * KeyWidthFactor;
  KeyPadding := KeyQSize * KeyPaddingLeftFactor;

  KeyRectF.Left := WholeRectF.Left + KeyPadding;
  KeyRectF.Top := WholeRectF.Top + KeyPadding;
  KeyRectF.Right := KeyRectF.Left + KeyQSize - 2 * KeyPadding;
  KeyRectF.Bottom := KeyRectF.Top + KeyQSize - 2 * KeyPadding;

  if ActivationKeyID <> 0 then
    KeyRenderManager.RenderSkia(Canvas, ActivationKeyID, KeyRectF, ksUp);

  TextRectF := TRectF.Create(KeyRectF.Right, WholeRectF.Top, WholeRectF.Right, WholeRectF.Bottom);

  Font := TSkFont.Create(TSkTypeface.MakeDefault, KeyQSize * 0.6);
  Text := Description;
  Font.MeasureText(Text, TextBounds);

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.Black;

  Canvas.DrawSimpleText(Text,
    TextRectF.Left + KeyPadding - TextBounds.Left,
    TextRectF.Top + (TextRectF.Height - TextBounds.Height) / 2 - TextBounds.Top,
    Font, Paint);
end;

procedure THelpSectionItem.RenderContentSkia(Canvas: ISkCanvas; const Rect: TRectF);
var
  Key: THelpKeyAssignmentItem;
  Y  : Single;
begin
  Y := Rect.Top + 10;
  for Key in FKeys do
  begin
    Key.Left := Round(Rect.Left + 20);
    Key.Top := Round(Y);
    // Ensure FAvailWidth is set for the item and height is calculated
    Key.GetRequiredHeight(Round(Rect.Width - 40));
    Key.RenderSkia(Canvas);
    Y := Y + Key.FRequiredHeight + 12; // Spacing
  end;
end;

procedure THelpSectionItem.AddKeyAssignment(Key: THelpKeyAssignmentItem);
begin
  FKeys.Add(Key);
end;

{ THelpKeyAssignmentItem }

function THelpKeyAssignmentItem.GetKeySizeRequired(AvailWidth: Integer): TSize;
begin
  Result.cx := Round(AvailWidth * KeySizeFactor);
  Result.cy := Result.cx;
end;

function THelpKeyAssignmentItem.GetRequiredHeight(AvailWidth: Integer): Integer;
var
  KeySize   : TSize;
  Paragraph : ISkParagraph;
  TextStartX: Single;
  TextStyle : ISkTextStyle;
  ParaStyle : ISkParagraphStyle;
  Builder   : ISkParagraphBuilder;
begin
  if (FAvailWidth = AvailWidth) and (FRequiredHeight > 0) then
    Exit(FRequiredHeight);

  KeySize := GetKeySizeRequired(AvailWidth);
  TextStartX := AvailWidth * TextStartXFactor;

  ParaStyle := TSkParagraphStyle.Create;
  Builder := TSkParagraphBuilder.Create(ParaStyle);
  TextStyle := TSkTextStyle.Create;
  TextStyle.FontSize := AvailWidth * KeySizeFactor * 0.6;
  TextStyle.FontFamilies := ['Arial'];
  Builder.PushStyle(TextStyle);
  Builder.AddText(Description);
  Builder.Pop;
  Paragraph := Builder.Build;
  Paragraph.Layout(AvailWidth - TextStartX - 20);

  Result := Round(Max(KeySize.cy, Paragraph.Height) + 8);
  FAvailWidth := AvailWidth;
  FRequiredHeight := Result;
end;

procedure THelpKeyAssignmentItem.RenderDescriptionSkia(Canvas: ISkCanvas; const Rect: TRectF; FontSize: Single);
var
  Paragraph : ISkParagraph;
  TextStyle : ISkTextStyle;
  ParaStyle : ISkParagraphStyle;
  Builder   : ISkParagraphBuilder;
begin
  ParaStyle := TSkParagraphStyle.Create;
  Builder := TSkParagraphBuilder.Create(ParaStyle);
  TextStyle := TSkTextStyle.Create;
  TextStyle.FontSize := FontSize;
  TextStyle.Color := TAlphaColors.Black;
  TextStyle.FontFamilies := ['Arial'];
  Builder.PushStyle(TextStyle);
  Builder.AddText(Description);
  Builder.Pop;
  Paragraph := Builder.Build;
  Paragraph.Layout(Rect.Width);
  Paragraph.Paint(Canvas, Rect.Left, Rect.Top + (Rect.Height - Paragraph.Height) / 2);
end;

procedure THelpKeyAssignmentItem.RenderSkia(Canvas: ISkCanvas);
var
  KeyPadding: Single;
  KeyRectF  : TRectF;
  KeySize   : TSize;
  TextRectF : TRectF;
  WholeRectF: TRectF;
begin
  WholeRectF := TRectF.Create(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeySize := GetKeySizeRequired(Round(WholeRectF.Width));
  KeyPadding := KeySize.cx * KeyPaddingLeftFactor;

  KeyRectF.Left := WholeRectF.Left + KeyPadding;
  KeyRectF.Top := WholeRectF.Top + KeyPadding;
  KeyRectF.Right := KeyRectF.Left + KeySize.cx - 2 * KeyPadding;
  KeyRectF.Bottom := KeyRectF.Top + KeySize.cy - 2 * KeyPadding;

  if Key <> 0 then
    KeyRenderManager.RenderSkia(Canvas, Key, KeyRectF, ksUp);

  TextRectF := TRectF.Create(WholeRectF.Left + WholeRectF.Width * TextStartXFactor,
    WholeRectF.Top, WholeRectF.Right, WholeRectF.Bottom);

  RenderDescriptionSkia(Canvas, TextRectF, WholeRectF.Width * KeySizeFactor * 0.6);
end;

{ THelp4ArrowKeysAssignmentItem }

function THelp4ArrowKeysAssignmentItem.GetKeySizeRequired(AvailWidth: Integer): TSize;
var
  Base: Integer;
begin
  Base := Round(AvailWidth * KeySizeFactor);
  Result.cx := Base * 3;
  if Shift <> [] then
    Result.cy := Base * 3
  else
    Result.cy := Base * 2;
end;

procedure THelp4ArrowKeysAssignmentItem.RenderSkia(Canvas: ISkCanvas);
var
  KeyPadding: Single;
  KeyQSize  : Single;
  KeyRectF  : TRectF;
  TextRectF : TRectF;
  WholeRectF: TRectF;
begin
  WholeRectF := TRectF.Create(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeyQSize := WholeRectF.Width * KeySizeFactor;
  KeyPadding := KeyQSize * KeyPaddingLeftFactor;

  KeyRectF.Left := WholeRectF.Left + KeyPadding;
  KeyRectF.Top := WholeRectF.Top + KeyPadding;

  // Render 4 arrows in a cross pattern
  KeyRenderManager.RenderSkia(Canvas, vkUp,    TRectF.Create(KeyRectF.Left + KeyQSize, KeyRectF.Top,            KeyRectF.Left + 2 * KeyQSize, KeyRectF.Top + KeyQSize), ksUp);
  KeyRenderManager.RenderSkia(Canvas, vkLeft,  TRectF.Create(KeyRectF.Left,            KeyRectF.Top + KeyQSize, KeyRectF.Left + KeyQSize,     KeyRectF.Top + 2 * KeyQSize), ksUp);
  KeyRenderManager.RenderSkia(Canvas, vkDown,  TRectF.Create(KeyRectF.Left + KeyQSize, KeyRectF.Top + KeyQSize, KeyRectF.Left + 2 * KeyQSize, KeyRectF.Top + 2 * KeyQSize), ksUp);
  KeyRenderManager.RenderSkia(Canvas, vkRight, TRectF.Create(KeyRectF.Left + 2 * KeyQSize, KeyRectF.Top + KeyQSize, KeyRectF.Left + 3 * KeyQSize, KeyRectF.Top + 2 * KeyQSize), ksUp);

  if ssShift in Shift then
    KeyRenderManager.RenderSkia(Canvas, vkShift, TRectF.Create(KeyRectF.Left, KeyRectF.Top + 2 * KeyQSize, KeyRectF.Left + 3 * KeyQSize, KeyRectF.Top + 3 * KeyQSize), ksUp);
  if ssCtrl in Shift then
    KeyRenderManager.RenderSkia(Canvas, vkControl, TRectF.Create(KeyRectF.Left, KeyRectF.Top + 2 * KeyQSize, KeyRectF.Left + 3 * KeyQSize, KeyRectF.Top + 3 * KeyQSize), ksUp);

  TextRectF := TRectF.Create(WholeRectF.Left + WholeRectF.Width * TextStartXFactor,
    WholeRectF.Top, WholeRectF.Right, WholeRectF.Bottom);

  RenderDescriptionSkia(Canvas, TextRectF, WholeRectF.Width * KeySizeFactor * 0.6);
end;

{ THelpAllDigitKeysAssignmentItem }

function THelpAllDigitKeysAssignmentItem.GetKeySizeRequired(AvailWidth: Integer): TSize;
var
  Base: Integer;
begin
  Base := Round(AvailWidth * KeySizeFactor);
  Result.cx := Base * 3;
  Result.cy := Base * 3;
end;

procedure THelpAllDigitKeysAssignmentItem.RenderSkia(Canvas: ISkCanvas);
var
  KeyPadding: Single;
  KeyQSize  : Single;
  KeyRectF  : TRectF;
  TextRectF : TRectF;
  WholeRectF: TRectF;
  X, Y      : Integer;
begin
  WholeRectF := TRectF.Create(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeyQSize := WholeRectF.Width * KeySizeFactor;
  KeyPadding := KeyQSize * KeyPaddingLeftFactor;

  KeyRectF.Left := WholeRectF.Left + KeyPadding;
  KeyRectF.Top := WholeRectF.Top + KeyPadding;

  // Render 1-9 in a 3x3 grid
  for Y := 0 to 2 do
    for X := 0 to 2 do
      KeyRenderManager.RenderSkia(Canvas, (2 - Y) * 3 + X + 1 + vk0,
        TRectF.Create(KeyRectF.Left + X * KeyQSize, KeyRectF.Top + Y * KeyQSize, KeyRectF.Left + (X + 1) * KeyQSize, KeyRectF.Top + (Y + 1) * KeyQSize), ksUp);

  TextRectF := TRectF.Create(WholeRectF.Left + WholeRectF.Width * TextStartXFactor,
    WholeRectF.Top, WholeRectF.Right, WholeRectF.Bottom);

  RenderDescriptionSkia(Canvas, TextRectF, WholeRectF.Width * KeySizeFactor * 0.6);
end;

{ THelpDigitAndDigitKeyAssignmentItem }

function THelpDigitAndDigitKeyAssignmentItem.GetKeySizeRequired(AvailWidth: Integer): TSize;
var
  Base: Integer;
begin
  Base := Round(AvailWidth * KeySizeFactor);
  Result.cx := Round(Base * 2.8);
  Result.cy := Base;
end;

procedure THelpDigitAndDigitKeyAssignmentItem.RenderSkia(Canvas: ISkCanvas);
var
  Font      : ISkFont;
  KeyPadding: Single;
  KeyQSize  : Single;
  KeyRectF  : TRectF;
  Paint     : ISkPaint;
  TextRectF : TRectF;
  WholeRectF: TRectF;
begin
  WholeRectF := TRectF.Create(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeyQSize := WholeRectF.Width * KeySizeFactor;
  KeyPadding := KeyQSize * KeyPaddingLeftFactor;

  KeyRectF.Left := WholeRectF.Left + KeyPadding;
  KeyRectF.Top := WholeRectF.Top + KeyPadding;

  // Render [1..9] + [1..9]
  KeyRenderManager.RenderSkia(Canvas, vk1, TRectF.Create(KeyRectF.Left, KeyRectF.Top, KeyRectF.Left + KeyQSize, KeyRectF.Top + KeyQSize), ksUp);

  Font := TSkFont.Create(TSkTypeface.MakeDefault, KeyQSize * 0.8);
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.Black;
  Canvas.DrawSimpleText('+', KeyRectF.Left + 1.1 * KeyQSize, KeyRectF.Top + KeyQSize * 0.8, Font, Paint);

  KeyRenderManager.RenderSkia(Canvas, vk1, TRectF.Create(KeyRectF.Left + 1.8 * KeyQSize, KeyRectF.Top, KeyRectF.Left + 2.8 * KeyQSize, KeyRectF.Top + KeyQSize), ksUp);

  TextRectF := TRectF.Create(WholeRectF.Left + WholeRectF.Width * TextStartXFactor,
    WholeRectF.Top, WholeRectF.Right, WholeRectF.Bottom);

  RenderDescriptionSkia(Canvas, TextRectF, KeyQSize * 0.5);
end;

end.
