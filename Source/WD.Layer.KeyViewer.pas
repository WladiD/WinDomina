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

    function AddLayerHelpSection(Layer: TBaseLayerClass): THelpSectionItem;
    procedure ChangeHelpSection(Section: THelpSectionItem);
    procedure SetInitProgress(const Value: Single);

    property InitProgress: Single read FInitProgress write SetInitProgress;

  public
    class constructor Create;
    constructor Create; override;
    destructor Destroy; override;

    procedure EnterLayer; override;
//    procedure ExitLayer; override;

    function HasMainContent: Boolean; override;
    procedure RenderMainContent(Target: TBitmap32); override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
  end;

  THelpBaseItem = class
  private
    function GetDescription: string;
  public
    DescriptionLangIndex: Integer;

    property Description: string read GetDescription;
  end;

  THelpSectionItem = class(THelpBaseItem)
  private
    FLayer: TBaseLayerClass;
    FKeys: TObjectList<THelpKeyAssignmentItem>;

  public
    ActivationKey: Integer;

    constructor Create(Layer: TBaseLayerClass);
    destructor Destroy; override;

    procedure AddKeyAssignment(Key: THelpKeyAssignmentItem);
  end;

  THelpKeyAssignmentItem = class(THelpBaseItem)
  private
    FSection: THelpSectionItem;

  public
    Shift: TShiftState;
    Key: Integer;
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

constructor TKeyViewerLayer.Create;
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
  inherited Create;

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

var
  HelpContentRect, LayersRect: TRect;
  BGColor: TColor32;
  HeadlinePoint: TPoint;
  EscKeyWidth: Integer;
  EscKeyRect: TRect;
  Points: TArrayOfFloatPoint;
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

  LayersRect := HelpContentRect;
  LayersRect.Right := LayersRect.Left + MonitorHandler.ConvertMmToPixel(80);
  HelpContentRect.Left := LayersRect.Right;

  Target.FillRect(HelpContentRect.Left, HelpContentRect.Top,
    HelpContentRect.Right, HelpContentRect.Bottom,
    EaseColor32(Color32(255, 255, 255, 0), clWhite32, InitProgress));

  Target.FillRect(LayersRect.Left, LayersRect.Top,
    LayersRect.Right, LayersRect.Bottom, clLightGray32);

  Target.Font.Height := HeightFactor(0.05);
  HeadlinePoint := Point(WidthFactor(IndentLeft), HeightFactor(0.04));
  Target.RenderText(HeadlinePoint.X, HeadlinePoint.Y, Lang[LS_16], -1, clWhite32);

  EscKeyWidth := Abs(Target.Font.Height); // MonitorHandler.ConvertMmToPixel(10);
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

  function GetActivationKey: Integer;
  var
    TestPair: TPair<Integer, TBaseLayer>;
  begin
    for TestPair in LayerActivationKeys.ToArray do
      if TestPair.Value.ClassType = Layer then
        Exit(TestPair.Key);

    Result := -1;
  end;

begin
  Result := THelpSectionItem.Create(Layer);
  Result.ActivationKey := GetActivationKey;
  FSections.Add(Result);
end;

procedure TKeyViewerLayer.ChangeHelpSection(Section: THelpSectionItem);
begin

end;

{ THelpBaseItem }

function THelpBaseItem.GetDescription: string;
begin
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

procedure THelpSectionItem.AddKeyAssignment(Key: THelpKeyAssignmentItem);
begin
  FKeys.Add(Key);
end;

end.
