unit WinDomina.Layer.Mover;

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

  GR32,
  GR32_Polygons,
  GR32_VectorUtils,
  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,
  AQPControlAnimations,

  WinDomina.Types,
  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools,
  WinDomina.WindowMatchSnap,
  WinDomina.Form.Number;

type
  TArrowIndicator = class;

  TMoverLayer = class(TBaseLayer)
  private
    class var
    AlignIndicatorAniID: Integer;
    ArrowIndicatorAniID: Integer;
  private
    type
    TNumberFormList = TObjectList<TNumberForm>;

    var
    FVisibleWindowList: TWindowList;
    FSwitchTargets: TWindowList;
    FNumberFormList: TNumberFormList;
    FArrowIndicator: TArrowIndicator;
    FShowNumberForms: Boolean;

    procedure UpdateVisibleWindowList;
    procedure UpdateSwitchTargetsWindowList;
    procedure CreateSwitchTargetNumberForms;

    function IsSwitchTargetNumKey(Key: Integer; out TargetIndex: Integer): Boolean;
    function HasSwitchTarget(TargetIndex: Integer; out Window: TWindow): Boolean;
    function HasSwitchTargetNumberForm(AssocWindowHandle: HWND; out Form: TNumberForm): Boolean;
    procedure SetShowNumberForms(NewValue: Boolean);

    procedure MoveSizeWindow(Direction: TDirection);
    procedure TargetWindowChangedOrMoved;

  public
    class constructor Create;
    constructor Create; override;
    destructor Destroy; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    procedure TargetWindowChanged; override;
    procedure TargetWindowMoved; override;
    procedure Invalidate; override;

    function HasMainContent: Boolean; override;
    procedure RenderMainContent(Target: TBitmap32); override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;

    property ShowNumberForms: Boolean read FShowNumberForms write SetShowNumberForms;
  end;

  TArrowIndicator = class
  private
    FParentLayer: TMoverLayer;
    FRefRect: TRect;

  public
    procedure Draw(Target: TBitmap32);

    property RefRect: TRect read FRefRect write FRefRect;
  end;

  TAlignIndicatorAnimation = class(TAnimationBase)
  private
    FFrom: TRect;
    FTo: TRect;

  public
    constructor Create(Layer: TBaseLayer; const AlignTarget, Workarea: TRect; Edge: TRectEdge);
    procedure Render(Target: TBitmap32); override;
  end;

implementation

function GetRefRectKeySquareSize(RefRect: TRect): Integer;
begin
  Result := Min(RefRect.Width, RefRect.Height);
  Result := Max(50, Round(Result * 0.1));
end;

{ TMoverLayer }

class constructor TMoverLayer.Create;
begin
  AlignIndicatorAniID := TAQ.GetUniqueID;
  ArrowIndicatorAniID := TAQ.GetUniqueID;
end;

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkM]);
  FArrowIndicator := TArrowIndicator.Create;
  FArrowIndicator.FParentLayer := Self;
  FNumberFormList := TNumberFormList.Create(True);
  FShowNumberForms := True;
end;

destructor TMoverLayer.Destroy;
begin
  FArrowIndicator.Free;
  FVisibleWindowList.Free;
  FSwitchTargets.Free;
  FNumberFormList.Free;

  inherited Destroy;
end;

procedure TMoverLayer.UpdateVisibleWindowList;
var
  WinHandle: HWND;
begin
  FVisibleWindowList.Free;
  FVisibleWindowList := WindowsHandler.CreateWindowList(wldAlignTargets);
  // Aktuell dominiertes Fenster aus der Liste entfernen
  if HasTargetWindow(WinHandle) then
    FVisibleWindowList.Remove(WinHandle);
  if Logging.HasWindowHandle(WinHandle) then
    FVisibleWindowList.Remove(WinHandle);
end;

procedure TMoverLayer.UpdateSwitchTargetsWindowList;
var
  WinHandle: HWND;
begin
  FSwitchTargets.Free;
  FSwitchTargets := WindowsHandler.CreateWindowList(wldSwitchTargets);
  if Logging.HasWindowHandle(WinHandle) then
    FSwitchTargets.Remove(WinHandle);
  CreateSwitchTargetNumberForms;
end;

procedure TMoverLayer.CreateSwitchTargetNumberForms;

  function CreateSwitchTargetNumberForm(AssocWindow: TWindow): TNumberForm;
  var
    KeySquareSize: Integer;
    WinRect: TRect;
  begin
    WinRect := AssocWindow.Rect;
    Result := TNumberForm.Create(nil);
    Result.AssignedToWindow := AssocWindow.Handle;
    KeySquareSize := GetRefRectKeySquareSize(WinRect);
    Result.Show;
    Result.SetBounds(WinRect.Left + ((WinRect.Width - KeySquareSize) div 2),
      WinRect.Top + ((WinRect.Height - KeySquareSize) div 2), KeySquareSize, KeySquareSize);
  end;

var
  cc, SwitchTargetsCount: Integer;
  NumberForm: TNumberForm;
begin
  if not ShowNumberForms then
    Exit;

  SwitchTargetsCount := Min(9, FSwitchTargets.Count - 1);

  for cc := SwitchTargetsCount downto 0 do
  begin
    NumberForm := CreateSwitchTargetNumberForm(FSwitchTargets[cc]);
    NumberForm.MainLabel.Caption := IntToStr(cc);
    FNumberFormList.Add(NumberForm);
  end;
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TMoverLayer.EnterLayer');
  FArrowIndicator.RefRect := TRect.Empty;

  TargetWindowChangedOrMoved;
  UpdateSwitchTargetsWindowList;
end;

procedure TMoverLayer.ExitLayer;
//var
//  FirstSwitchTargetWindow, TargetWindow: TWindow;
begin
  AddLog('TMoverLayer.ExitLayer');

  // Die Rangfolge wiederherstellen. Damit das aktivierte Fenster nicht in den Hintergrund wandert.
//  if HasSwitchTarget(0, FirstSwitchTargetWindow) and HasTargetWindow(TargetWindow) and
//    (TargetWindow.Handle <> FirstSwitchTargetWindow.Handle) then
//    BringWindowToTop(FirstSwitchTargetWindow.Handle);

  FNumberFormList.Clear;

  inherited ExitLayer;
end;

function TMoverLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

procedure TMoverLayer.RenderMainContent(Target: TBitmap32);
begin
  inherited RenderMainContent(Target);

  FArrowIndicator.Draw(Target);
end;

function TMoverLayer.HasSwitchTargetNumberForm(AssocWindowHandle: HWND;
  out Form: TNumberForm): Boolean;
var
  TestForm: TNumberForm;
begin
  for TestForm in FNumberFormList do
    if TestForm.AssignedToWindow = AssocWindowHandle then
    begin
      Form := TestForm;
      Exit(True);
    end;

  Result := False;
end;

procedure TMoverLayer.SetShowNumberForms(NewValue: Boolean);
begin
  if NewValue = FShowNumberForms then
    Exit;

  FShowNumberForms := NewValue;

  if NewValue then
    UpdateSwitchTargetsWindowList
  else
    FNumberFormList.Clear;
end;

procedure TMoverLayer.TargetWindowChangedOrMoved;
var
  TargetWindow: TWindow;
  RectLocal: TRect;
  NumberForm: TNumberForm;
  KeySquareSize: Integer;
begin
  if not HasTargetWindow(TargetWindow) then
    Exit;

  RectLocal := MonitorHandler.ScreenToClient(TargetWindow.Rect);

  Take(FArrowIndicator)
    .CancelAnimations(ArrowIndicatorAniID)
    .Plugin<TAQPSystemTypesAnimations>
    .RectAnimation(RectLocal,
        function(RefObject: TObject): TRect
        begin
          Result := TArrowIndicator(RefObject).RefRect;
        end,
        procedure(RefObject: TObject; const NewRect: TRect)
        begin
          TArrowIndicator(RefObject).RefRect := NewRect;
          InvalidateMainContent;
        end, 500, ArrowIndicatorAniID, TAQ.Ease(TEaseType.etElastic));

  if HasSwitchTargetNumberForm(TargetWindow.Handle, NumberForm) then
  begin
    RectLocal := TargetWindow.Rect;
    KeySquareSize := GetRefRectKeySquareSize(RectLocal);

    Take(NumberForm)
      .CancelAnimations(ArrowIndicatorAniID)
      .Plugin<TAQPControlAnimations>
      .BoundsAnimation(
        RectLocal.Left + ((RectLocal.Width - KeySquareSize) div 2),
        RectLocal.Top + ((RectLocal.Height - KeySquareSize) div 2),
        KeySquareSize, KeySquareSize, 250, ArrowIndicatorAniID, TAQ.Ease(TEaseType.etElastic));
  end;
end;

procedure TMoverLayer.TargetWindowChanged;
begin
  TargetWindowChangedOrMoved;
end;

procedure TMoverLayer.TargetWindowMoved;
begin
  TargetWindowChangedOrMoved;
end;

procedure TMoverLayer.Invalidate;
begin
  TargetWindowChangedOrMoved;
end;

function TMoverLayer.IsSwitchTargetNumKey(Key: Integer; out TargetIndex: Integer): Boolean;
begin
  Result := True;

  if Key in [vkNumpad0..vkNumpad9] then
    TargetIndex := (Key - vkNumpad0)
  else if Key in [vk0..vk9] then
    TargetIndex := (Key - vk0)
  else
    Result := False;
end;

function TMoverLayer.HasSwitchTarget(TargetIndex: Integer; out Window: TWindow): Boolean;
begin
  Result := Assigned(FSwitchTargets) and (TargetIndex >= 0) and
    (TargetIndex < FSwitchTargets.Count);
  if Result then
    Window := FSwitchTargets[TargetIndex];
end;

procedure TMoverLayer.MoveSizeWindow(Direction: TDirection);
var
  Window: HWND;
  WinRect, MatchRect, WorkareaRect: TRect;
  NewPos: TPoint;
  MatchEdge: TRectEdge;
  MatchWindow: TWindow;
  Snapper: TWindowMatchSnap;
  AdjacentMonitor: TMonitor;

  // Da MatchRect hauptsächlich für die Animationen existiert, verkleinern wir es in bestimmten
  // Fällen, damit wir dennoch eine mehr auffälligere Animation bekommen.
  procedure IndentMatchRect;
  const
    IndentFactor = 0.45;
  var
    Indent: Integer;
  begin
    case Direction of
      dirLeft, dirRight:
      begin
        Indent := Trunc(MatchRect.Height * IndentFactor);
        Inc(MatchRect.Top, Indent);
        Dec(MatchRect.Bottom, Indent);
      end;
      dirUp, dirDown:
      begin
        Indent := Trunc(MatchRect.Width * IndentFactor);
        Inc(MatchRect.Left, Indent);
        Dec(MatchRect.Right, Indent);
      end;
    end;
  end;

  procedure AdjustXOnAdjacentMonitor;
  begin
    if NewPos.X < AdjacentMonitor.WorkareaRect.Left then
      NewPos.X := AdjacentMonitor.WorkareaRect.Left
    else if (NewPos.X + WinRect.Width) > AdjacentMonitor.WorkareaRect.Right then
      NewPos.X := AdjacentMonitor.WorkareaRect.Right - WinRect.Width;
  end;

  procedure AdjustYOnAdjacentMonitor;
  begin
    if NewPos.Y < AdjacentMonitor.WorkareaRect.Top then
      NewPos.Y := AdjacentMonitor.WorkareaRect.Top
    else if (NewPos.Y + WinRect.Height) > AdjacentMonitor.WorkareaRect.Bottom then
      NewPos.Y := AdjacentMonitor.WorkareaRect.Bottom - WinRect.Height;
  end;

begin
  if not HasTargetWindow(Window) then
    Exit;

  Snapper := nil;

  // Sollte die Animation noch laufen, so muss sie abgebrochen werden
  WindowPositioner.EnterWindow(Window);
  try
    GetWindowRect(Window, WinRect);
    WorkareaRect := GetWorkareaRect(WinRect);
    GetWindowRectDominaStyle(Window, WinRect);

    UpdateVisibleWindowList;
    NewPos := TPoint.Zero;
    MatchRect := TRect.Empty;
    MatchEdge := reUnknown;

    Snapper := TWindowMatchSnap.Create(WinRect, WorkareaRect, FVisibleWindowList);
    Snapper.AddPhantomWorkareaCenterWindows;

    // Zuerst suchen wir nach einer benachbarten Fensterkante...
    if
      (
        (Direction = dirLeft) and
        Snapper.HasMatchSnapWindowLeft(MatchWindow, MatchEdge, NewPos)
      ) or
      (
        (Direction = dirRight) and
        Snapper.HasMatchSnapWindowRight(MatchWindow, MatchEdge, NewPos)
      ) or
      (
        (Direction = DirUp) and
        Snapper.HasMatchSnapWindowTop(MatchWindow, MatchEdge, NewPos)
      ) or
      (
        (Direction = dirDown) and
        Snapper.HasMatchSnapWindowBottom(MatchWindow, MatchEdge, NewPos)
      ) then
    begin
      MatchRect := MatchWindow.Rect;
      IndentMatchRect;
    end
    // ...hier angekommen suchen wir nach einer Arbeitskante.
    else if
      (
        (Direction = dirLeft) and
        Snapper.HasWorkAreaEdgeMatchLeft(MatchEdge, NewPos)
      ) or
      (
        (Direction = dirRight) and
        Snapper.HasWorkAreaEdgeMatchRight(MatchEdge, NewPos)
      ) or
      (
        (Direction = dirUp) and
        Snapper.HasWorkAreaEdgeMatchTop(MatchEdge, NewPos)
      ) or
      (
        (Direction = dirDown) and
        Snapper.HasWorkAreaEdgeMatchBottom(MatchEdge, NewPos)
      )
      then
    begin
      MatchRect := WorkareaRect;
      MatchRect.Inflate(-4, -4);
      IndentMatchRect;
    end
    // Suche nach einem benachbartem Monitor
    else if MonitorHandler.HasAdjacentMonitor(Direction, AdjacentMonitor) then
    begin
      MonitorHandler.CurrentMonitor := AdjacentMonitor;
      NewPos := WinRect.Location;
      case Direction of
        dirLeft:
        begin
          NewPos.X := AdjacentMonitor.WorkareaRect.Right - WinRect.Width;
          AdjustYOnAdjacentMonitor;
        end;
        dirRight:
        begin
          NewPos.X := AdjacentMonitor.WorkareaRect.Left;
          AdjustYOnAdjacentMonitor;
        end;
        dirUp:
        begin
          NewPos.Y := AdjacentMonitor.WorkareaRect.Bottom - WinRect.Height;
          AdjustXOnAdjacentMonitor;
        end;
        dirDown:
        begin
          NewPos.Y := AdjacentMonitor.WorkareaRect.Top;
          AdjustXOnAdjacentMonitor;
        end;
      else
        Exit;
      end;
    end
    // Nichts trifft zu, also raus hier
    else
      Exit;

    // WinRect enthält ab hier die neue Position
    WinRect.TopLeft := NewPos;
    WindowPositioner.MoveWindow(NewPos);

    if not MatchRect.IsEmpty then
      AddAnimation(TAlignIndicatorAnimation.Create(Self, MatchRect, WorkareaRect, MatchEdge), 500,
        AlignIndicatorAniID);
  finally
    Snapper.Free;
    WindowPositioner.ExitWindow;
  end;
end;

procedure TMoverLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  function IsDirectionKey: Boolean;
  var
    Direction: TDirection;
  begin
    Result := WinDomina.Types.IsDirectionKey(Key, Direction);
    if Result then
      MoveSizeWindow(Direction);
  end;

  function IsSwitchTargetNumKey: Boolean;
  var
    SwitchTargetIndex: Integer;
    SwitchTargetWindow, TargetWindow: TWindow;
  begin
    Result := Self.IsSwitchTargetNumKey(Key, SwitchTargetIndex) and
      HasSwitchTarget(SwitchTargetIndex, SwitchTargetWindow) and
      HasTargetWindow(TargetWindow) and (TargetWindow.Handle <> SwitchTargetWindow.Handle);
    if Result then
      BringWindowToTop(SwitchTargetWindow.Handle);
  end;

  function IsSpaceKey: Boolean;
  begin
    Result := Key = vkSpace;
    if Result then
      ShowNumberForms := not ShowNumberForms;
  end;

begin
  if WindowsHandler.GetWindowList(wldDominaTargets).Count = 0 then
    Exit;

  Handled := IsDirectionKey or IsSwitchTargetNumKey or IsSpaceKey;
end;

procedure TMoverLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

{ TAlignIndicatorAnimation }

constructor TAlignIndicatorAnimation.Create(Layer: TBaseLayer; const AlignTarget, Workarea: TRect;
  Edge: TRectEdge);
const
  XMargin = 4;
  YMargin = 4;
begin
  inherited Create(Layer);

  case Edge of
    reTop:
    begin
      FFrom := Rect(AlignTarget.Left, AlignTarget.Top - YMargin,
        AlignTarget.Right, AlignTarget.Top + YMargin);
      FTo := FFrom;
      FTo.Left := Workarea.Left;
      FTo.Right := Workarea.Right;
    end;
    reBottom:
    begin
      FFrom := Rect(AlignTarget.Left, AlignTarget.Bottom - YMargin,
        AlignTarget.Right, AlignTarget.Bottom + YMargin);
      FTo := FFrom;
      FTo.Left := Workarea.Left;
      FTo.Right := Workarea.Right;
    end;
    reLeft:
    begin
      FFrom := Rect(AlignTarget.Left - XMargin, AlignTarget.Top,
        AlignTarget.Left + XMargin, AlignTarget.Bottom);
      FTo := FFrom;
      FTo.Top := Workarea.Top;
      FTo.Bottom := Workarea.Bottom;
    end;
    reRight:
    begin
      FFrom := Rect(AlignTarget.Right - XMargin, AlignTarget.Top,
        AlignTarget.Right + XMargin, AlignTarget.Bottom);
      FTo := FFrom;
      FTo.Top := Workarea.Top;
      FTo.Bottom := Workarea.Bottom;
    end;
  end;
end;

procedure TAlignIndicatorAnimation.Render(Target: TBitmap32);
var
  CurRect: TRect;
begin
  CurRect := Layer.MonitorHandler.ScreenToClient(
    TAQ.EaseRect(FFrom, FTo, FProgress, etSinus));
  Target.FillRectTS(CurRect, clWhite32);
  CurRect.Inflate(-2, -2);
  Target.FillRectTS(CurRect, clBlack32);
end;

{ TArrowIndicator }

procedure TArrowIndicator.Draw(Target: TBitmap32);
var
  ContainSquare, ArrowSquare, ArrowIndent, RemainWidth, RemainHeight: Integer;
  ArrowSquare2, ArrowSquare3, ArrowRemainSquare: Integer;
  ArrowRemainHalfSquare: Single;
  PaintRect, ArrowRect: TRect;

  procedure DrawArrowRect;
  begin
    Target.FillRectTS(ArrowRect, SetAlpha(clWhite32, 250));
    Target.FrameRectTS(ArrowRect, clBlack32);
    ArrowRect.Inflate(1, 1);
    Target.FrameRectTS(ArrowRect, clBlack32);
  end;

  procedure DrawArrow(const P1, P2, P3: TFloatPoint);
  var
    Points: TArrayOfFloatPoint;
  begin
    SetLength(Points, 3);
    Points[0] := P1;
    Points[1] := P2;
    Points[2] := P3;

    PolygonFS(Target, Points, clBlack32);
  end;

begin
  ArrowSquare := GetRefRectKeySquareSize(RefRect);
  ArrowSquare2 := ArrowSquare * 2;
  ArrowSquare3 := ArrowSquare * 3;
  ContainSquare := ArrowSquare3;
  ArrowIndent := Round(ArrowSquare * 0.25);
  ArrowRemainSquare := ArrowSquare - (ArrowIndent * 2);
  ArrowRemainHalfSquare := ArrowRemainSquare / 2;

  RemainWidth := (RefRect.Width - ContainSquare) div 2;
  RemainHeight := (RefRect.Height - ContainSquare) div 2;

  PaintRect := Rect(RefRect.Left + RemainWidth, RefRect.Top + RemainHeight,
    RefRect.Right - RemainWidth, RefRect.Bottom - RemainHeight);

  // Pfeil nach Oben
  ArrowRect := Rect(PaintRect.Left + ArrowSquare, PaintRect.Top,
    PaintRect.Left + ArrowSquare2, PaintRect.Top + ArrowSquare);
  DrawArrowRect;
  DrawArrow(
    FloatPoint(ArrowRect.Left + ArrowIndent + ArrowRemainHalfSquare, ArrowRect.Top + ArrowIndent),
    FloatPoint(ArrowRect.Right - ArrowIndent, ArrowRect.Bottom - ArrowIndent),
    FloatPoint(ArrowRect.Left + ArrowIndent, ArrowRect.Bottom - ArrowIndent));

  // Pfeil nach Rechts
  ArrowRect := Rect(PaintRect.Left + ArrowSquare2, PaintRect.Top + ArrowSquare,
    PaintRect.Left + ArrowSquare3, PaintRect.Top + ArrowSquare2);
  DrawArrowRect;
  DrawArrow(
    FloatPoint(ArrowRect.Left + ArrowIndent, ArrowRect.Top + ArrowIndent),
    FloatPoint(ArrowRect.Right - ArrowIndent, ArrowRect.Top + ArrowIndent + ArrowRemainHalfSquare),
    FloatPoint(ArrowRect.Left + ArrowIndent, ArrowRect.Bottom - ArrowIndent));

  // Pfeil nach Unten
  ArrowRect := Rect(PaintRect.Left + ArrowSquare, PaintRect.Top + ArrowSquare2,
    PaintRect.Left + ArrowSquare2, PaintRect.Top + ArrowSquare3);
  DrawArrowRect;
  DrawArrow(
    FloatPoint(ArrowRect.Left + ArrowIndent, ArrowRect.Top + ArrowIndent),
    FloatPoint(ArrowRect.Right - ArrowIndent, ArrowRect.Top + ArrowIndent),
    FloatPoint(ArrowRect.Left + ArrowIndent + ArrowRemainHalfSquare, ArrowRect.Bottom - ArrowIndent));

  // Pfeil nach Links
  ArrowRect := Rect(PaintRect.Left, PaintRect.Top + ArrowSquare,
    PaintRect.Left + ArrowSquare, PaintRect.Top + ArrowSquare2);
  DrawArrowRect;
  DrawArrow(
    FloatPoint(ArrowRect.Left + ArrowIndent, ArrowRect.Top + ArrowIndent + ArrowRemainHalfSquare),
    FloatPoint(ArrowRect.Right - ArrowIndent, ArrowRect.Top + ArrowIndent),
    FloatPoint(ArrowRect.Right - ArrowIndent, ArrowRect.Bottom - ArrowIndent));
end;

end.
