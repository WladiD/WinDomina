unit WD.Layer.KeyViewer;

interface

uses
  GR32,
  GR32_Polygons,
  GR32_VectorUtils,

  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Generics.Collections,
  System.Contnrs,
  System.Math,
  System.Diagnostics,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,

  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,
  AQPControlAnimations,
  Localization,

  WD.Types,
  WD.Layer,
  WD.Layer.Mover,
  WD.Layer.Grid,
  WD.Registry,
  WD.WindowTools,
  WD.WindowMatchSnap,
  WD.Form.Number,
  WD.KeyTools,
  WD.KeyDecorators,
  WD.LangIndex,
  WD.GR32Tools;

type
  THelpBaseItem = class;
  THelpSectionItem = class;
  THelpKeyAssignmentItem = class;

  TKeyViewerLayer = class(TBaseLayer)
  private
    class var
    InitAniID: Integer;
  private
    FSections: TObjectList<THelpSectionItem>;
    FInitProgress: Single;
    FActiveHelpSection: THelpSectionItem;

    function AddLayerHelpSection(Layer: TBaseLayerClass): THelpSectionItem;
    procedure SetActiveSection(Value: THelpSectionItem);
    procedure SetActiveSectionByLayer(Layer: TBaseLayer);
    function HasActiveSectionByKey(Key: Integer; out Section: THelpSectionItem): Boolean;

    procedure SetInitProgress(const Value: Single);

    property InitProgress: Single read FInitProgress write SetInitProgress;
    property ActiveHelpSection: THelpSectionItem read FActiveHelpSection write SetActiveSection;

  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure EnterLayer; override;
//    procedure ExitLayer; override;

    function HasMainContent: Boolean; override;
    procedure RenderMainContent(Target: TBitmap32); override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
  end;

  THelpBaseItem = class
  private
    FLeft: Integer;
    FTop: Integer;

    function GetDescription: string;

  public
    DescriptionLangIndex: Integer;
    DescriptionCustom: string;

    function GetRequiredHeight(AvailWidth: Integer): Integer; virtual; abstract;
    procedure Render(Target: TBitmap32); virtual; abstract;

    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
    property Description: string read GetDescription;
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
    FLayer: TBaseLayerClass;
    FKeys: TObjectList<THelpKeyAssignmentItem>;
    FAvailWidth: Integer;
    FRequiredHeight: Integer;
    FHeadline: string;

  public
    ActivationKey: Integer;

    constructor Create(Layer: TBaseLayerClass);
    destructor Destroy; override;

    function GetRequiredHeight(AvailWidth: Integer): Integer; override;
    procedure Render(Target: TBitmap32); override;

    procedure AddKeyAssignment(Key: THelpKeyAssignmentItem);
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
    FSection: THelpSectionItem;
    FAvailWidth: Integer;
    FRequiredHeight: Integer;

  protected
    function GetKeySizeRequired(AvailWidth: Integer): TSize; virtual;

  public
    Shift: TShiftState;
    Key: Integer;

    function GetRequiredHeight(AvailWidth: Integer): Integer; override;
    procedure Render(Target: TBitmap32); override;
  end;

  THelpKeyAssignmentItemClass = class of THelpKeyAssignmentItem;

  THelp4ArrowKeysAssignmentItem = class(THelpKeyAssignmentItem)

  end;

  THelpAllDigitKeysAssignmentItem = class(THelpKeyAssignmentItem)

  end;

  THelpDigitAndDigitKeyAssignmentItem = class(THelpKeyAssignmentItem)

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

function TKeyViewerLayer.HasActiveSectionByKey(Key: Integer;
  out Section: THelpSectionItem): Boolean;
var
  CheckSection: THelpSectionItem;
begin
  for CheckSection in FSections do
    if CheckSection.ActivationKey = Key then
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

procedure TKeyViewerLayer.RenderMainContent(Target: TBitmap32);
const
  IndentTop = 0.1;
  IndentLeft = 0.1;
  IndentRight = 0.1;
  IndentBottom = 0.05;

  function WidthFactor(Factor: Real): Integer;
  begin
    Result := Round(Target.Width * Factor * InitProgress);
  end;

  function HeightFactor(Factor: Real): Integer;
  begin
    Result := Round(Target.Height * Factor * InitProgress);
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
  HelpContentRect, SectionsRect: TRect;
  BGColor: TColor32;
  HeadlinePoint: TPoint;
  EscKeyWidth: Integer;
  EscKeyRect: TRect;
  Points: TArrayOfFloatPoint;
  MaxRequiredSectionHeight: Integer;

  procedure RenderSections;
  var
    Section: THelpSectionItem;
    Y: Integer;
  begin
    Y := SectionsRect.Top;
    for Section in FSections do
    begin
      Section.Left := SectionsRect.Left;
      Section.Top := Y;
      Inc(Y, MaxRequiredSectionHeight);
      Section.Render(Target);
    end;
  end;

  procedure RenderActiveSection(Alpha: Single);
  begin
    if Alpha <= 0 then
      Exit;


  end;

begin
  inherited RenderMainContent(Target);

  BGColor := EaseColor32(TColor32(0), Color32(0, 0, 0, 240), InitProgress);

  HelpContentRect := Rect(
    WidthFactor(IndentLeft), HeightFactor(IndentTop),
    Target.Width - WidthFactor(IndentRight), Target.Height - HeightFactor(IndentBottom));

  Target.FillRect(0, 0, HelpContentRect.Left, Target.Height, BGColor);
  Target.FillRect(HelpContentRect.Left, 0, HelpContentRect.Right, HelpContentRect.Top, BGColor);
  Target.FillRect(HelpContentRect.Right, 0, Target.Width, Target.Height, BGColor);
  Target.FillRect(HelpContentRect.Left, HelpContentRect.Bottom, HelpContentRect.Right, Target.Height, BGColor);

  SectionsRect := HelpContentRect;
  SectionsRect.Right := SectionsRect.Left + MonitorHandler.ConvertMmToPixel(80);
  HelpContentRect.Left := SectionsRect.Right;

  Target.FillRect(HelpContentRect.Left, HelpContentRect.Top,
    HelpContentRect.Right, HelpContentRect.Bottom,
    EaseColor32(Color32(255, 255, 255, 0), clWhite32, InitProgress));

  Target.FillRect(SectionsRect.Left, SectionsRect.Top,
    SectionsRect.Right, SectionsRect.Bottom, clLightGray32);

  Target.Font.Height := HeightFactor(0.05);
  HeadlinePoint := Point(WidthFactor(IndentLeft), HeightFactor(0.04));
  Target.RenderTextWD(HeadlinePoint.X, HeadlinePoint.Y, Lang[LS_16], clWhite32);

  EscKeyWidth := Max(1, Abs(Target.Font.Height)); // MonitorHandler.ConvertMmToPixel(10);
  Dec(HeadlinePoint.X, 10 + EscKeyWidth);

  EscKeyRect := Rect(EscKeyWidth, HeadlinePoint.Y,
    EscKeyWidth * 2, HeadlinePoint.Y + EscKeyWidth);

  Target.FillRect(EscKeyRect.Left, EscKeyRect.Top, EscKeyRect.Right, EscKeyRect.Bottom, clWhite32);
  KeyRenderManager.Render(Target, vkEscape, EscKeyRect, ksFlat);

  // Arrow to the left on the left side of the [Esc] key
  EscKeyRect.Offset(-EscKeyWidth, 0);
  EscKeyRect.Inflate(-Round(EscKeyRect.Width * 0.6), -Round(EscKeyRect.Height * 0.6));
  EscKeyRect.NormalizeRect;

  SetLength(Points, 3);
  Points[0] := TFloatPoint.Create(EscKeyRect.Right, EscKeyRect.Top);
  Points[1] := TFloatPoint.Create(EscKeyRect.Left, EscKeyRect.Top + EscKeyRect.Height / 2);
  Points[2] := TFloatPoint.Create(EscKeyRect.Right, EscKeyRect.Bottom);
  PolylineFS(Target, Points, clWhite32, False, 3);

  MaxRequiredSectionHeight := GetMaxRequiredSectionHeight(SectionsRect.Width);
  RenderSections;
  RenderActiveSection(Max(0, (InitProgress - 0.8) / 0.2));
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
  TestPair: TPair<Integer, TBaseLayer>;
begin
  Result := THelpSectionItem.Create(Layer);
  FSections.Add(Result);

  for TestPair in LayerActivationKeys.ToArray do
    if TestPair.Value.ClassType = Layer then
    begin
      Result.ActivationKey := TestPair.Key;
      Result.DescriptionCustom := TestPair.Value.GetDisplayName;
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
    CalcTarget: TBitmap32;
    HeadlineRect: TRect;
    KeyHeight: Integer;
  begin
    CalcTarget := TBitmap32.Create(AvailWidth, 200);
    try
      CalcTarget.Font.Size := HeadlineFontSize;

      KeyHeight := Round(AvailWidth * KeyWidthFactor);
      HeadlineRect.Left := KeyHeight + HeadlinePaddingLeft;
      HeadlineRect.Top := HeadlinePaddingTop;
      HeadlineRect.Right := AvailWidth - HeadlinePaddingRight;
      HeadlineRect.Bottom := CalcTarget.Height;

      CalcTarget.Textout(HeadlineRect, DT_LEFT or DT_SINGLELINE or DT_CALCRECT, Description);
      Result := HeadlineRect.Height;
      if KeyHeight > Result then
        Result := KeyHeight;
    finally
      CalcTarget.Free;
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

procedure THelpSectionItem.Render(Target: TBitmap32);
var
  WholeRect, KeyRect, TextRect: TRect;
  KeyQSize: Integer;
  KeyPaddingLeft, KeyPaddingRight, KeyPaddingTop, KeyPaddingBottom: Integer;
  Text: string;
  TextExt: TSize;
  TextX, TextY: Integer;
begin
  WholeRect := Rect(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeyQSize := Round(WholeRect.Width * KeyWidthFactor);
  KeyPaddingLeft := Round(KeyQSize * KeyPaddingLeftFactor);
  KeyPaddingRight := Round(KeyQSize * KeyPaddingRightFactor);
  KeyPaddingTop := Round(KeyQSize * KeyPaddingTopFactor);
  KeyPaddingBottom := Round(KeyQSize * KeyPaddingBottomFactor);

  KeyRect.Left := WholeRect.Left + KeyPaddingLeft;
  KeyRect.Top := WholeRect.Top + KeyPaddingTop;
  KeyRect.Right := KeyRect.Left + KeyQSize - KeyPaddingRight - KeyPaddingLeft;
  KeyRect.Bottom := KeyRect.Top + KeyQSize - KeyPaddingBottom - KeyPaddingTop;

  if ActivationKey <> 0 then
    KeyRenderManager.Render(Target, ActivationKey, KeyRect, ksUp);

  TextRect := Rect(KeyRect.Right, WholeRect.Top, WholeRect.Right, WholeRect.Bottom);

  Target.Font.Height := -Round(KeyQSize * 0.6); //HeadlineFontSize;
  Text := Description;
  TextExt := Target.TextExtent(Text);
  TextX := TextRect.Left + KeyPaddingLeft; // + ((TextRect.Width - TextExt.cx) div 2);
  TextY := TextRect.Top + ((TextRect.Height - TextExt.cy) div 2);

  Target.RenderTextWD(TextX, TextY, Text, clBlack32);
end;

procedure THelpSectionItem.AddKeyAssignment(Key: THelpKeyAssignmentItem);
begin
  FKeys.Add(Key);
end;

{ THelpKeyAssignmentItem }

function THelpKeyAssignmentItem.GetKeySizeRequired(AvailWidth: Integer): TSize;
begin
  Result.cx := Round(AvailWidth * 0.15);
  Result.cy := Result.cx;
end;

function THelpKeyAssignmentItem.GetRequiredHeight(AvailWidth: Integer): Integer;

  function CalcRequiredHeight: Integer;
  var
    CalcTarget: TBitmap32;
    HeadlineRect: TRect;
    KeySize: TSize;
  begin
    CalcTarget := TBitmap32.Create(AvailWidth, 200);
    try
      CalcTarget.Font.Size := HeadlineFontSize;

      KeySize := GetKeySizeRequired(AvailWidth);
      HeadlineRect.Left := KeySize.cx + HeadlinePaddingLeft;
      HeadlineRect.Top := HeadlinePaddingTop;
      HeadlineRect.Right := AvailWidth - HeadlinePaddingRight;
      HeadlineRect.Bottom := CalcTarget.Height;

      CalcTarget.Textout(HeadlineRect, DT_LEFT or DT_SINGLELINE or DT_CALCRECT, Description);
      Result := HeadlineRect.Height;
      if KeySize.cy > Result then
        Result := KeySize.cy;
    finally
      CalcTarget.Free;
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

procedure THelpKeyAssignmentItem.Render(Target: TBitmap32);
var
  WholeRect, KeyRect, TextRect: TRect;
  KeySize: TSize;
  KeyPaddingLeft, KeyPaddingRight, KeyPaddingTop, KeyPaddingBottom: Integer;
  Text: string;
  TextExt: TSize;
  TextX, TextY: Integer;
begin
  WholeRect := Rect(Left, Top, Left + FAvailWidth, Top + FRequiredHeight);

  KeySize := GetKeySizeRequired(WholeRect.Width);
  KeyPaddingLeft := Round(KeySize.cx * KeyPaddingLeftFactor);
  KeyPaddingRight := Round(KeySize.cx * KeyPaddingRightFactor);
  KeyPaddingTop := Round(KeySize.cy * KeyPaddingTopFactor);
  KeyPaddingBottom := Round(KeySize.cy * KeyPaddingBottomFactor);

  KeyRect.Left := WholeRect.Left + KeyPaddingLeft;
  KeyRect.Top := WholeRect.Top + KeyPaddingTop;
  KeyRect.Right := KeyRect.Left + KeySize.cx - KeyPaddingRight - KeyPaddingLeft;
  KeyRect.Bottom := KeyRect.Top + KeySize.cy - KeyPaddingBottom - KeyPaddingTop;

  if Key <> 0 then
    KeyRenderManager.Render(Target, Key, KeyRect, ksUp);

  TextRect := Rect(KeyRect.Right, WholeRect.Top, WholeRect.Right, WholeRect.Bottom);

  Target.Font.Height := -Round(KeySize.cy * 0.6); //HeadlineFontSize;
  Text := Description;
  TextExt := Target.TextExtent(Text);
  TextX := TextRect.Left + KeyPaddingLeft; // + ((TextRect.Width - TextExt.cx) div 2);
  TextY := TextRect.Top + ((TextRect.Height - TextExt.cy) div 2);

  Target.RenderTextWD(TextX, TextY, Text, clBlack32);
end;

end.
