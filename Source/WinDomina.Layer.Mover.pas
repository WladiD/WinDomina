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
  Vcl.Controls,

  GR32,
  GR32_Polygons,
  GR32_VectorUtils,
  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,
  AQPControlAnimations,
  SendInputHelper,

  WinDomina.Types,
  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools,
  WinDomina.WindowMatchSnap,
  WinDomina.Form.Number,
  WinDomina.KeyTools;

type
  TArrowIndicator = class;

  TMoverLayer = class(TBaseLayer)
  private
    class var
    AlignIndicatorAniID: Integer;
    ArrowIndicatorAniID: Integer;
    ArrowIndicatorAniDuration: Integer;
    NumberFormBoundsAniID: Integer;
    VirtualClick1DelayID: Integer;
  private
    type
    TNumberFormList = TObjectList<TNumberForm>;

    var
    FVisibleWindowList: TWindowList;
    FSwitchTargets: TWindowList;
    FNumberFormList: TNumberFormList;
    FArrowIndicator: TArrowIndicator;
    FShowNumberForms: Boolean;
    FActiveSwitchTargetIndex: Integer;
    FClickOnSwitchTarget: Boolean;

    procedure UpdateVisibleWindowList;
    procedure UpdateSwitchTargetsWindowList;
    procedure CreateSwitchTargetNumberForms;

    function IsSwitchTargetNumKey(Key: Integer; out TargetIndex: Integer): Boolean;
    function HasSwitchTarget(TargetIndex: Integer; out Window: TWindow): Boolean;
    function HasSwitchTargetNumberForm(AssocWindowHandle: HWND; out Form: TNumberForm): Boolean;
    function HasSwitchTargetNumberFormByIndex(TargetIndex: Integer; out Form: TNumberForm): Boolean;
    function HasSwitchTargetIndex(AssocWindowHandle: HWND; out TargetIndex: Integer): Boolean;
    procedure VirtualClickOnSwitchTargetNumberForm(AssocWindowHandle: HWND; Delay: Integer);
    procedure BringSwitchTargetNumberFormsToTop;
    procedure SetActiveSwitchTargetIndex(Value: Integer);
    procedure SetShowNumberForms(NewValue: Boolean);

    procedure MoveSizeWindow(Direction: TDirection);
    procedure TargetWindowChangedOrMoved;

    property ActiveSwitchTargetIndex: Integer read FActiveSwitchTargetIndex write SetActiveSwitchTargetIndex;

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
    FTargetIndex: Integer;
    FShowTargetIndex: Boolean;

  public
    procedure Draw(Target: TBitmap32);

    property RefRect: TRect read FRefRect write FRefRect;
    property TargetIndex: Integer read FTargetIndex write FTargetIndex;
    property ShowTargetIndex: Boolean read FShowTargetIndex write FShowTargetIndex;
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
  ArrowIndicatorAniDuration := 500;
  NumberFormBoundsAniID := TAQ.GetUniqueID;
  VirtualClick1DelayID := TAQ.GetUniqueID;
end;

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkM]);
  FArrowIndicator := TArrowIndicator.Create;
  FArrowIndicator.FParentLayer := Self;
  FArrowIndicator.ShowTargetIndex := False;
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
    NumberForm.Number := cc;
    if cc = ActiveSwitchTargetIndex then
      NumberForm.Hide;
    FNumberFormList.Add(NumberForm);
  end;

  BringSwitchTargetNumberFormsToTop;
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TMoverLayer.EnterLayer');
  FArrowIndicator.RefRect := TRect.Empty;

  ActiveSwitchTargetIndex := 0;
  TargetWindowChangedOrMoved;
  UpdateSwitchTargetsWindowList;
end;

procedure TMoverLayer.ExitLayer;
begin
  // Der virtuelle Klick darf nicht ausgeführt werden, wenn der Layer verlassen wird und
  // ein Klick noch erfolgen soll.
  FClickOnSwitchTarget := False;
  Take(Self).CancelDelays(VirtualClick1DelayID).Die;

  FNumberFormList.Clear;
  ActiveSwitchTargetIndex := -1;

  AddLog('TMoverLayer.ExitLayer');

  inherited ExitLayer;
end;

function TMoverLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

procedure TMoverLayer.RenderMainContent(Target: TBitmap32);
var
  NumberForm: TNumberForm;
  Rect: TRect;
begin
  inherited RenderMainContent(Target);

  FArrowIndicator.Draw(Target);

  if HasSwitchTargetNumberFormByIndex(ActiveSwitchTargetIndex, NumberForm) then
  begin
    Rect := MonitorHandler.ScreenToClient(NumberForm.BoundsRect);
    KeyRenderManager.Render(Target, ActiveSwitchTargetIndex + vk0, Rect, ksFlat);
  end;
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

function TMoverLayer.HasSwitchTargetNumberFormByIndex(TargetIndex: Integer;
  out Form: TNumberForm): Boolean;
var
  TestForm: TNumberForm;
begin
  for TestForm in FNumberFormList do
    if TestForm.Number = TargetIndex then
    begin
      Form := TestForm;
      Exit(True);
    end;

  Result := False;
end;

function TMoverLayer.HasSwitchTargetIndex(AssocWindowHandle: HWND;
  out TargetIndex: Integer): Boolean;
var
  cc: Integer;
begin
  if Assigned(FSwitchTargets) then
  begin
    for cc := 0 to FSwitchTargets.Count - 1 do
      if FSwitchTargets[cc].Handle = AssocWindowHandle then
      begin
        TargetIndex := cc;
        Exit(True);
      end;
  end;

  Result := False;
end;

// Führt einen virtuellen Mausklick auf das Zielfensterkürzel aus
//
// Auf diese Weise wird das Hauptfenster aktiviert, dies ist unverzichtbar für ein korrektes Setzen
// des ForegroundWindow.
procedure TMoverLayer.VirtualClickOnSwitchTargetNumberForm(AssocWindowHandle: HWND; Delay: Integer);
var
  NumberForm: TNumberForm;
  Center: TPoint;
  Window: TWindow;
  ClickFunction: TEachFunction;
begin
  if HasSwitchTargetNumberForm(AssocWindowHandle, NumberForm) then
    Center := NumberForm.BoundsRect.CenterPoint
  else if HasSwitchTarget(ActiveSwitchTargetIndex, Window) then
    Center := Window.Rect.CenterPoint
  else
    Exit;

  ClickFunction :=
    function(AQ: TAQ; O: TObject): Boolean
    var
      SIH: TSendInputHelper;
    begin
      SIH := TSendInputHelper.Create;
      try
        SIH.AddAbsoluteMouseMove(Center.X, Center.Y);
        SIH.AddMouseClick(mbLeft);
        SIH.Flush;
      finally
        SIH.Free;
      end;
      Result := True;
    end;

  if Delay > 0 then
    Take(Self)
      .CancelDelays(VirtualClick1DelayID)
      .EachDelay(Delay, ClickFunction, VirtualClick1DelayID)
  else
    ClickFunction(nil, nil);
end;

procedure TMoverLayer.BringSwitchTargetNumberFormsToTop;
var
  NumberForm: TNumberForm;
begin
//  Logging.AddLog('BringSwitchTargetNumberFormsToTop called');

  for NumberForm in FNumberFormList do
    if NumberForm.Visible then
      SetWindowPos(NumberForm.Handle, HWND_TOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

procedure TMoverLayer.SetActiveSwitchTargetIndex(Value: Integer);
var
  NumberForm: TNumberForm;
begin
  if Value = FActiveSwitchTargetIndex then
    Exit;

  // Vorheriges einblenden
  if HasSwitchTargetNumberFormByIndex(FActiveSwitchTargetIndex, NumberForm) then
    NumberForm.Visible := True;

  // Neues ausblenden
  if HasSwitchTargetNumberFormByIndex(Value, NumberForm) then
    NumberForm.Visible := False;

  FActiveSwitchTargetIndex := Value;
  FArrowIndicator.TargetIndex := Value;
  InvalidateMainContent;
end;

procedure TMoverLayer.SetShowNumberForms(NewValue: Boolean);
begin
  if NewValue = FShowNumberForms then
    Exit;

  FShowNumberForms := NewValue;
  FArrowIndicator.ShowTargetIndex := not NewValue;

  if NewValue then
    UpdateSwitchTargetsWindowList
  else
    FNumberFormList.Clear;

  InvalidateMainContent;
end;

procedure TMoverLayer.TargetWindowChangedOrMoved;
var
  TargetWindow, ActiveSwitchTargetWindow: TWindow;
  RectLocal: TRect;
  NumberForm: TNumberForm;
  KeySquareSize, SwitchTargetIndex: Integer;
begin
  if not HasTargetWindow(TargetWindow) then
    Exit;

  if HasSwitchTargetIndex(TargetWindow.Handle, SwitchTargetIndex) then
    ActiveSwitchTargetIndex := SwitchTargetIndex
  else
    ActiveSwitchTargetIndex := -1;

  if HasSwitchTargetNumberForm(TargetWindow.Handle, NumberForm) then
  begin
    RectLocal := TargetWindow.Rect;
    KeySquareSize := GetRefRectKeySquareSize(RectLocal);
    // Damit die Fenster während einer Fensterbewegung nicht permanent nach vorne geholt
    // werden müssen, wird dies nur bei einer nicht laufender Animation gemacht.
    if not TAQ.HasActiveActors([arAnimation], NumberForm, NumberFormBoundsAniID) then
      BringSwitchTargetNumberFormsToTop;

    Take(NumberForm)
      .CancelAnimations(NumberFormBoundsAniID)
      .Plugin<TAQPControlAnimations>
      .BoundsAnimation(
        RectLocal.Left + ((RectLocal.Width - KeySquareSize) div 2),
        RectLocal.Top + ((RectLocal.Height - KeySquareSize) div 2),
        KeySquareSize, KeySquareSize, 250, NumberFormBoundsAniID, TAQ.Ease(TEaseType.etElastic));
  end
  // Wenn die ShowNumbers nicht eingeblendet sind, dann müssen bei Fensterbewegung die
  // Fensterpositionen in FSwitchTargets aktualisiert werden
  else if HasSwitchTarget(ActiveSwitchTargetIndex, ActiveSwitchTargetWindow) then
    ActiveSwitchTargetWindow.Rect := TargetWindow.Rect;

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
        end, ArrowIndicatorAniDuration, ArrowIndicatorAniID, TAQ.Ease(TEaseType.etElastic),
        procedure(Sender: TObject)
        begin
          if FClickOnSwitchTarget then
          begin
            VirtualClickOnSwitchTargetNumberForm(TargetWindow.Handle, 0);
            FClickOnSwitchTarget := False;
          end;
        end);
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

    BringSwitchTargetNumberFormsToTop;

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
      HasTargetWindow(TargetWindow);
    if Result then
    begin
      if TargetWindow.Handle <> SwitchTargetWindow.Handle then
      begin
        BringWindowToTop(SwitchTargetWindow.Handle);
        BringSwitchTargetNumberFormsToTop;
      end;

      ActiveSwitchTargetIndex := SwitchTargetIndex;

      if ShowNumberForms then
        VirtualClickOnSwitchTargetNumberForm(SwitchTargetWindow.Handle, ArrowIndicatorAniDuration)
      else
        FClickOnSwitchTarget := SwitchTargetIndex >= 0;
    end;
  end;

  function IsSpaceKey: Boolean;
  begin
    Result := Key = vkSpace;
    if Result then
    begin
      ShowNumberForms := not ShowNumberForms;
      Invalidate;
    end;
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
  ContainSquare, ArrowSquare, RemainWidth, RemainHeight: Integer;
  ArrowSquare2, ArrowSquare3: Integer;
  PaintRect, ArrowRect: TRect;
begin
  ArrowSquare := GetRefRectKeySquareSize(RefRect);
  ArrowSquare2 := ArrowSquare * 2;
  ArrowSquare3 := ArrowSquare * 3;
  ContainSquare := ArrowSquare3;

  RemainWidth := (RefRect.Width - ContainSquare) div 2;
  RemainHeight := (RefRect.Height - ContainSquare) div 2;

  PaintRect := Rect(RefRect.Left + RemainWidth, RefRect.Top + RemainHeight,
    RefRect.Right - RemainWidth, RefRect.Bottom - RemainHeight);

  if ShowTargetIndex and (TargetIndex >= 0) then
    KeyRenderManager.Render(Target, TargetIndex + vk0,
      Rect(PaintRect.Left + ArrowSquare, PaintRect.Top + ArrowSquare,
      PaintRect.Left + ArrowSquare2, PaintRect.Top + ArrowSquare2), ksFlat);

  // Pfeil nach Oben
  ArrowRect := Rect(PaintRect.Left + ArrowSquare - 1, PaintRect.Top - 1,
    PaintRect.Left + ArrowSquare2 + 1, PaintRect.Top + ArrowSquare + 1);
  KeyRenderManager.Render(Target, vkUp, ArrowRect, ksFlat);

  // Pfeil nach Rechts
  ArrowRect := Rect(PaintRect.Left + ArrowSquare2 - 1, PaintRect.Top + ArrowSquare - 1,
    PaintRect.Left + ArrowSquare3 + 1, PaintRect.Top + ArrowSquare2 + 1);
  KeyRenderManager.Render(Target, vkRight, ArrowRect, ksFlat);

  // Pfeil nach Unten
  ArrowRect := Rect(PaintRect.Left + ArrowSquare - 1, PaintRect.Top + ArrowSquare2 - 1,
    PaintRect.Left + ArrowSquare2 + 1, PaintRect.Top + ArrowSquare3 + 1);
  KeyRenderManager.Render(Target, vkDown, ArrowRect, ksFlat);

  // Pfeil nach Links
  ArrowRect := Rect(PaintRect.Left - 1, PaintRect.Top + ArrowSquare - 1,
    PaintRect.Left + ArrowSquare + 1, PaintRect.Top + ArrowSquare2 + 1);
  KeyRenderManager.Render(Target, vkLeft, ArrowRect, ksFlat);
end;

end.
