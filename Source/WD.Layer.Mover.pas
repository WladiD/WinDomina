// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.Layer.Mover;

interface

uses

  Winapi.Windows,

  System.Classes,
  System.Contnrs,
  System.Generics.Collections,
  System.Math,
  System.Skia,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.Forms,

  AnyiQuack,
  AQPControlAnimations,
  AQPSystemTypesAnimations,
  SendInputHelper,
  WindowEnumerator,

  WD.Form.Number,
  WD.KeyDecorators,
  WD.KeyTools,
  WD.Layer,
  WD.Registry,
  WD.Types,
  WD.WindowMatchSnap,
  WD.WindowTools;

type

  TArrowIndicator = class;
  TControlMode = (cmWindow, cmMouse);
  TWindowControlMode = (wcmMoveWindow, wcmGrowWindow, wcmShrinkWindow);

  TMoverLayer = class(TBaseLayer)
  private
    class var
    AlignIndicatorAniID      : Integer;
    ArrowIndicatorAniDuration: Integer;
    ArrowIndicatorAniID      : Integer;
    MouseMoveAniID           : Integer;
    NumberFormBoundsAniID    : Integer;
  private
    type
    TNumberFormList = TObjectDictionary<Integer, TNumberForm>;
    var
    FActiveSwitchTargetIndex: Integer;
    FArrowIndicator         : TArrowIndicator;
    FClickOnSwitchTarget    : Boolean;
    FControlMode            : TControlMode;
    FNumberFormList         : TNumberFormList;
    FShowNumberForms        : Boolean;
    FSwitchTargets          : TWindowList;
    FVisibleWindowList      : TWindowList;
    FWindowMode             : TWindowControlMode;

    procedure BringSwitchTargetNumberFormsToTop;
    procedure CreateSwitchTargetNumberForms;
    function  HasSwitchTarget(TargetIndex: Integer; out Window: TWindow): Boolean;
    function  HasSwitchTargetIndex(AssocWindowHandle: HWND; out TargetIndex: Integer): Boolean;
    function  HasSwitchTargetNumberForm(AssocWindowHandle: HWND; out Form: TNumberForm): Boolean;
    function  HasSwitchTargetNumberFormByIndex(TargetIndex: Integer; out Form: TNumberForm): Boolean;
    function  IsSwitchTargetNumKey(Key: Integer; out TargetIndex: Integer): Boolean;
    function  IsWindowModeModifierKey(Key: Integer): Boolean;
    procedure MoveSizeWindow(Direction: TDirection);
    procedure SetActiveSwitchTargetIndex(Value: Integer);
    procedure SetShowNumberForms(NewValue: Boolean);
    procedure SetWindowMode(Value: TWindowControlMode);
    procedure TargetWindowChangedOrMoved;
    procedure UpdateCurrentWindowMode;
    procedure UpdateSwitchTargetNumberFormBounds(NumberForm: TNumberForm);
    procedure UpdateSwitchTargetsWindowList;
    procedure UpdateVisibleWindowList;
    procedure VirtualClickOnSwitchTargetNumberForm(AssocWindowHandle: HWND; MoveCursorDuration: Integer);

    property ActiveSwitchTargetIndex: Integer read FActiveSwitchTargetIndex write SetActiveSwitchTargetIndex;
    property ControlMode            : TControlMode read FControlMode write FControlMode;
    property WindowMode             : TWindowControlMode read FWindowMode write SetWindowMode;
  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor  Destroy; override;
    procedure EnterLayer; override;
    procedure ExitLayer; override;
    procedure TargetWindowChanged; override;
    procedure TargetWindowMoved; override;
    procedure Invalidate; override;
    function  HasMainContent: Boolean; override;
    function  HitTest(const Point: TPoint): Boolean; override;
    procedure RenderMainContentSkia(Canvas: ISkCanvas); override;
    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;
    property ShowNumberForms: Boolean read FShowNumberForms write SetShowNumberForms;
  end;

  TArrowIndicator = class
  private
    FParentLayer    : TMoverLayer;
    FRefRect        : TRect;
    FShowTargetIndex: Boolean;
    FTargetIndex    : Integer;
    FWindowMode     : TWindowControlMode;
  public
    procedure DrawSkia(Canvas: ISkCanvas);
    function  HitTest(const Point: TPoint): Boolean;
    property RefRect: System.Types.TRect read FRefRect write FRefRect;
    property TargetIndex: Integer read FTargetIndex write FTargetIndex;
    property ShowTargetIndex: Boolean read FShowTargetIndex write FShowTargetIndex;
    property WindowMode: TWindowControlMode read FWindowMode write FWindowMode;
  end;

  TAlignIndicatorAnimation = class(TAnimationBase)
  private
    FFrom: System.Types.TRect;
    FTo  : System.Types.TRect;
  public
    constructor Create(Layer: TBaseLayer; const AlignTarget, Workarea: System.Types.TRect; Edge: TRectEdge);
    procedure RenderSkia(Canvas: ISkCanvas); override;
  end;

implementation

function GetRefRectKeySquareSize(RefRect: System.Types.TRect): Integer;
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
  MouseMoveAniID := TAQ.GetUniqueID;
end;

constructor TMoverLayer.Create(Owner: TComponent);
begin
  inherited Create(Owner);
  RegisterLayerActivationKeys([vkM]);
  FArrowIndicator := TArrowIndicator.Create;
  FArrowIndicator.FParentLayer := Self;
  FArrowIndicator.ShowTargetIndex := False;
  FNumberFormList := TNumberFormList.Create([doOwnsValues]);
  FShowNumberForms := True;
  FExclusive := True;
  FActiveSwitchTargetIndex := -1;
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
var
  cc                : Integer;
  NumberForm        : TNumberForm;
  SwitchTargetsCount: Integer;
begin
  if not ShowNumberForms then
    Exit;
  SwitchTargetsCount := Min(9, FSwitchTargets.Count - 1);
  for cc := SwitchTargetsCount downto 0 do
  begin
    NumberForm := TNumberForm.Create(nil);
    NumberForm.AssignedToWindow := FSwitchTargets[cc].Handle;
    NumberForm.Number := cc;
    FNumberFormList.Add(cc, NumberForm);
  end;
  for NumberForm in FNumberFormList.Values do
  begin
    NumberForm.Show;
    UpdateSwitchTargetNumberFormBounds(NumberForm);
  end;
  BringSwitchTargetNumberFormsToTop;
end;

procedure TMoverLayer.UpdateCurrentWindowMode;
begin
  if ControlMode <> cmWindow then
    Exit
  else if WDMKeyStates.IsControlKeyPressed then
    WindowMode := wcmGrowWindow
  else if WDMKeyStates.IsShiftKeyPressed then
    WindowMode := wcmShrinkWindow
  else
    WindowMode := wcmMoveWindow;
end;

procedure TMoverLayer.UpdateSwitchTargetNumberFormBounds(NumberForm: TNumberForm);

  function GetTargetRect(AssocWindow: TWindow): TRect;
  var
    KeySquareSize: Integer;
    WinRect      : TRect;
  begin
    WinRect := AssocWindow.Rect;
    KeySquareSize := GetRefRectKeySquareSize(WinRect);
    Result.Left := WinRect.Left + ((WinRect.Width - KeySquareSize) div 2);
    Result.Top := WinRect.Top + ((WinRect.Height - KeySquareSize) div 2);
    Result.Right := Result.Left + KeySquareSize;
    Result.Bottom := Result.Top + KeySquareSize;
  end;

var
  AssocWindow    : TWindow;
  Collision      : Boolean;
  DeltaX         : Integer;
  DeltaY         : Integer;
  TargetRect     : TRect;
  TestAssocWindow: TWindow;
  TestBoundsRect : TRect;
  TestNF         : TNumberForm;
  TestTargetRect : TRect;
begin
  if not (Assigned(NumberForm) and HasSwitchTarget(NumberForm.Number, AssocWindow)) then
    Exit;

  TargetRect := GetTargetRect(AssocWindow);

  for TestNF in FNumberFormList.Values do
  begin
    if (TestNF = NumberForm) or not HasSwitchTarget(TestNF.Number, TestAssocWindow) then
      Continue;

    TestTargetRect := GetTargetRect(TestAssocWindow);
    Collision := TargetRect.IntersectsWith(TestTargetRect);
    if Collision then
    begin
      TestBoundsRect := TestTargetRect;
      DeltaX := 0;
      DeltaY := 0;

      if
        (TargetRect.Left < TestBoundsRect.Right) and
        (TargetRect.Right > TestBoundsRect.Right) then
        DeltaX := -(TestBoundsRect.Right - TargetRect.Left)
      else if
        (TargetRect.Right > TestBoundsRect.Left) and
        (TargetRect.Left < TestBoundsRect.Right) then
        DeltaX := TargetRect.Right - TestBoundsRect.Left;

      if
        (TargetRect.Top < TestBoundsRect.Bottom) and
        (TargetRect.Bottom > TestBoundsRect.Bottom) then
        DeltaY := -(TestBoundsRect.Bottom - TargetRect.Top)
      else if
        (TargetRect.Bottom > TestBoundsRect.Top) and
        (TargetRect.Top < TestBoundsRect.Bottom) then
        DeltaY := TargetRect.Bottom - TestBoundsRect.Top;

      if Abs(DeltaX) > Abs(DeltaY) then
        DeltaX := 0
      else
        DeltaY := 0;

      if (DeltaX <> 0) or (DeltaY <> 0)
        then TestBoundsRect.Offset(DeltaX, DeltaY);
    end
    else
      TestBoundsRect := TestTargetRect;

    if TestBoundsRect <> TestNF.BoundsRect then
      Take(TestNF)
        .CancelAnimations(NumberFormBoundsAniID)
        .Plugin<TAQPControlAnimations>
        .BoundsAnimation(
          TestBoundsRect.Left,
          TestBoundsRect.Top,
          TestBoundsRect.Width,
          TestBoundsRect.Height,
          250,
          NumberFormBoundsAniID,
          TAQ.Ease(TEaseType.etElastic));
  end;

  SetWindowPos(NumberForm.WindowHandle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

  Take(NumberForm)
    .CancelAnimations(NumberFormBoundsAniID)
    .Plugin<TAQPControlAnimations>
    .BoundsAnimation(
      TargetRect.Left,
      TargetRect.Top,
      TargetRect.Width,
      TargetRect.Height,
      250,
      NumberFormBoundsAniID,
      TAQ.Ease(TEaseType.etElastic),
      procedure(Sender: TObject)
      begin
        SetWindowPos(TNumberForm(Sender).WindowHandle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
      end);
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  FArrowIndicator.RefRect := TRect.Empty;
  ControlMode := cmWindow;
  WindowMode := wcmMoveWindow;
  ActiveSwitchTargetIndex := 0;
  TargetWindowChangedOrMoved;
  UpdateSwitchTargetsWindowList;
end;

procedure TMoverLayer.ExitLayer;
begin
  FClickOnSwitchTarget := False;
  Take(Mouse).CancelAnimations(MouseMoveAniID);
  FNumberFormList.Clear;
  ActiveSwitchTargetIndex := -1;
  inherited ExitLayer;
end;

function TMoverLayer.HasMainContent: Boolean;
begin
  Result := IsLayerActive;
end;

function TMoverLayer.HitTest(const Point: TPoint): Boolean;
var
  NumberForm: TNumberForm;
  Rect      : TRect;
begin
  if not IsLayerActive then
    Exit(False);

  if FArrowIndicator.HitTest(Point) then
    Exit(True);

  if HasSwitchTargetNumberFormByIndex(ActiveSwitchTargetIndex, NumberForm) then
  begin
    Rect := MonitorHandler.ScreenToClient(NumberForm.BoundsRect);
    if Rect.Contains(Point) then
      Exit(True);
  end;

  Result := False;
end;

procedure TMoverLayer.RenderMainContentSkia(Canvas: ISkCanvas);
var
  NumberForm: TNumberForm;
  Rect      : TRect;
begin
  inherited RenderMainContentSkia(Canvas);
  FArrowIndicator.DrawSkia(Canvas);
  if HasSwitchTargetNumberFormByIndex(ActiveSwitchTargetIndex, NumberForm) then
  begin
    Rect := MonitorHandler.ScreenToClient(NumberForm.BoundsRect);
    KeyRenderManager.RenderSkia(Canvas, ActiveSwitchTargetIndex + vk0, TRectF.Create(Rect), ksFlat);
  end;
end;

function TMoverLayer.HasSwitchTargetNumberForm(AssocWindowHandle: HWND; out Form: TNumberForm): Boolean;
var
  TestForm: TNumberForm;
begin
  for TestForm in FNumberFormList.Values do
    if TestForm.AssignedToWindow = AssocWindowHandle then
    begin
      Form := TestForm;
      Exit(True);
    end;
  Result := False;
end;

function TMoverLayer.HasSwitchTargetNumberFormByIndex(TargetIndex: Integer; out Form: TNumberForm): Boolean;
begin
  Result := FNumberFormList.TryGetValue(TargetIndex, Form);
end;

function TMoverLayer.HasSwitchTargetIndex(AssocWindowHandle: HWND; out TargetIndex: Integer): Boolean;
var
  Idx: Integer;
begin
  if Assigned(FSwitchTargets) then
    for Idx := 0 to FSwitchTargets.Count - 1 do
      if FSwitchTargets[Idx].Handle = AssocWindowHandle then
      begin
        TargetIndex := Idx;
        Exit(True);
      end;
  Result := False;
end;

procedure TMoverLayer.VirtualClickOnSwitchTargetNumberForm(AssocWindowHandle: HWND; MoveCursorDuration: Integer);
var
  ClickProc     : TProc;
  GetCenterPoint: TFunc<TPoint>;
  NumberForm    : TNumberForm;
  TargetP       : TPoint;
  Window        : TWindow;
begin
  if HasSwitchTargetNumberForm(AssocWindowHandle, NumberForm) then
    GetCenterPoint :=
      function: TPoint
      begin
        Result := NumberForm.BoundsRect.CenterPoint;
      end
  else if HasSwitchTarget(ActiveSwitchTargetIndex, Window) then
    GetCenterPoint :=
      function: TPoint
      begin
        Result := Window.Rect.CenterPoint;
      end
  else
    Exit;

  ClickProc :=
    procedure
    var
      SIH          : TSendInputHelper;
      PointedWindow: HWND;

      function IsOwnWindow(AHandle: HWND): Boolean;
      var
        NF: TNumberForm;
      begin
        Result := (AHandle = Application.MainFormHandle);
        if not Result then
          for NF in FNumberFormList.Values do
            if NF.WindowHandle = AHandle then
              Exit(True);
      end;

    begin
      PointedWindow := FindWindowFromPoint(Mouse.CursorPos);
      if not ((PointedWindow <> 0) and IsOwnWindow(PointedWindow)) then
        Exit;
      SIH := TSendInputHelper.Create;
      try
        SIH.AddMouseClick(mbLeft);
        SIH.Flush;
      finally
        SIH.Free;
      end;
    end;

  TargetP := GetCenterPoint;
  if Mouse.CursorPos = TargetP then
  begin
    ClickProc;
    Exit;
  end;
  Mouse.CursorPos := TargetP;
  ClickProc;
end;

procedure TMoverLayer.BringSwitchTargetNumberFormsToTop;
var
  NumberForm: TNumberForm;
begin
  for NumberForm in FNumberFormList.Values do
    if NumberForm.Visible then
      SetWindowPos(NumberForm.WindowHandle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

procedure TMoverLayer.SetActiveSwitchTargetIndex(Value: Integer);
var
  NumberForm: TNumberForm;
begin
  if Value = FActiveSwitchTargetIndex then
    Exit;

  if HasSwitchTargetNumberFormByIndex(FActiveSwitchTargetIndex, NumberForm) then
  begin
    NumberForm.Visible := True;
    UpdateSwitchTargetNumberFormBounds(NumberForm);
  end;
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

procedure TMoverLayer.SetWindowMode(Value: TWindowControlMode);
begin
  if Value = FWindowMode then
    Exit;

  FWindowMode := Value;
  FArrowIndicator.WindowMode := Value;
  InvalidateMainContent;
end;

procedure TMoverLayer.TargetWindowChangedOrMoved;
var
  ActiveSwitchTargetWindow: TWindow;
  NumberForm              : TNumberForm;
  RectLocal               : TRect;
  SwitchTargetIndex       : Integer;
  TargetWindow            : TWindow;
begin
  if not HasTargetWindow(TargetWindow) then
    Exit;

  if HasSwitchTargetIndex(TargetWindow.Handle, SwitchTargetIndex) then
    ActiveSwitchTargetIndex := SwitchTargetIndex
  else
    ActiveSwitchTargetIndex := -1;

  if HasSwitchTarget(ActiveSwitchTargetIndex, ActiveSwitchTargetWindow) then
    ActiveSwitchTargetWindow.Rect := TargetWindow.Rect;

  if HasSwitchTargetNumberForm(TargetWindow.Handle, NumberForm) then
  begin
    if not TAQ.HasActiveActors([arAnimation], NumberForm, NumberFormBoundsAniID) then
      BringSwitchTargetNumberFormsToTop;
    UpdateSwitchTargetNumberFormBounds(NumberForm);
  end;

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
            VirtualClickOnSwitchTargetNumberForm(TargetWindow.Handle, 300);
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

function TMoverLayer.IsWindowModeModifierKey(Key: Integer): Boolean;
begin
  Result :=
    (ControlMode = cmWindow) and
    (Key in [vkControl, vkLControl, vkRControl, vkShift, vkLShift, vkRShift]);
end;

function TMoverLayer.HasSwitchTarget(TargetIndex: Integer; out Window: TWindow): Boolean;
begin
  Result :=
    Assigned(FSwitchTargets) and
    (TargetIndex >= 0) and
    (TargetIndex < FSwitchTargets.Count);

  if Result then
    Window := FSwitchTargets[TargetIndex];
end;

procedure TMoverLayer.MoveSizeWindow(Direction: TDirection);
var
  AdjacentMonitor: TMonitor;
  FromDPI        : Integer;
  FromMonitor    : TMonitor;
  MatchEdge      : TRectEdge;
  MatchRect      : TRect;
  MatchWindow    : TWindow;
  NewPos         : TPoint;
  Snapper        : TWindowMatchSnap;
  TargetDPI      : Integer;
  Window         : HWND;
  WinRect        : TRect;
  WorkareaRect   : TRect;

  function GetSnapperRefRect: TRect;
  const
    RefEdge: array [TDirection] of TRectEdge = (
      reUnknown, // dirUnknown
      reBottom,  // dirUp
      reLeft,    // dirRight
      reTop,     // dirDown
      reRight    // dirLeft
      );
  begin
    // For window shrink mode we need other ref rects as for move and grow
    if WindowMode = wcmShrinkWindow then
      Result := GetRectEdgeRect(WinRect, RefEdge[Direction])
    else
      Result := WinRect;
  end;

  function ConvertDiffDPI(Value: Integer): Integer;
  begin
    if FromDPI <> TargetDPI then
      Result := Round(Value / FromDPI * TargetDPI)
    else
      Result := Value;
  end;

  procedure AdjustXOnAdjacentMonitor;
  begin
    if NewPos.X < AdjacentMonitor.WorkareaRect.Left then
      NewPos.X := AdjacentMonitor.WorkareaRect.Left
    else if (NewPos.X + ConvertDiffDPI(WinRect.Width)) > AdjacentMonitor.WorkareaRect.Right then
      NewPos.X := AdjacentMonitor.WorkareaRect.Right - ConvertDiffDPI(WinRect.Width);
  end;

  procedure AdjustYOnAdjacentMonitor;
  begin
    if NewPos.Y < AdjacentMonitor.WorkareaRect.Top then
      NewPos.Y := AdjacentMonitor.WorkareaRect.Top
    else if (NewPos.Y + ConvertDiffDPI(WinRect.Height)) > AdjacentMonitor.WorkareaRect.Bottom then
      NewPos.Y := AdjacentMonitor.WorkareaRect.Bottom - ConvertDiffDPI(WinRect.Height);
  end;

begin
  if not HasTargetWindow(Window) then
    Exit;

  WindowPositioner.EnterWindow(Window);
  Snapper := nil;
  try
    GetWindowRectDominaStyle(Window, WinRect);
    WorkareaRect := GetWorkareaRect(WinRect);
    UpdateVisibleWindowList;
    NewPos := TPoint.Zero;
    MatchRect := TRect.Empty;
    MatchEdge := reUnknown;
    FromDPI := 0;
    TargetDPI := 0;

    Snapper := TWindowMatchSnap.Create(GetSnapperRefRect, WorkareaRect, FVisibleWindowList);
    if WindowMode = wcmMoveWindow then
      Snapper.AddPhantomWorkareaCenterWindows;

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
        (Direction = dirUp) and
        Snapper.HasMatchSnapWindowTop(MatchWindow, MatchEdge, NewPos)
      ) or
      (
        (Direction = dirDown) and
        Snapper.HasMatchSnapWindowBottom(MatchWindow, MatchEdge, NewPos)
      ) then
    begin
       MatchRect := MatchWindow.Rect;
    end
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
      ) then
    begin
      MatchRect := WorkareaRect;
      MatchRect.Inflate(-4, -4);
    end
    else if MonitorHandler.HasAdjacentMonitor(Direction, AdjacentMonitor) then
    begin
      FromMonitor := MonitorHandler.CurrentMonitor;
      MonitorHandler.CurrentMonitor := AdjacentMonitor;
      FromDPI := FromMonitor.PixelsPerInch;
      TargetDPI := AdjacentMonitor.PixelsPerInch;
      NewPos := WinRect.Location;
      case Direction of
        dirLeft:  NewPos.X := AdjacentMonitor.WorkareaRect.Right - ConvertDiffDPI(WinRect.Width);
        dirRight: NewPos.X := AdjacentMonitor.WorkareaRect.Left;
        dirUp:    NewPos.Y := AdjacentMonitor.WorkareaRect.Bottom - ConvertDiffDPI(WinRect.Height);
        dirDown:  NewPos.Y := AdjacentMonitor.WorkareaRect.Top;
      end;
      AdjustXOnAdjacentMonitor;
      AdjustYOnAdjacentMonitor;
    end
    else
      Exit;

    if WindowMode = wcmGrowWindow then
    begin
      if Direction in [dirRight, dirDown] then
      begin
        WinRect.Width := WinRect.Width + (NewPos.X - WinRect.Left);
        WinRect.Height := WinRect.Height + (NewPos.Y - WinRect.Top);
      end
      else if Direction in [dirLeft, dirUp] then
        WinRect.TopLeft := NewPos;
      WindowPositioner.PlaceWindow(WinRect);
    end
    else if WindowMode = wcmShrinkWindow then
    begin
      case Direction of
        dirUp: WinRect.Bottom := NewPos.Y;
        dirRight: WinRect.Left := NewPos.X;
        dirDown: WinRect.Top := NewPos.Y;
        dirLeft: WinRect.Right := NewPos.X;
      end;

      if
        (WinRect.Left < WinRect.Right) and
        (WinRect.Top < WinRect.Bottom) and
        NoSnap(WinRect.Left, WinRect.Right, 100) and
        NoSnap(WinRect.Top, WinRect.Bottom, 100) then
        WindowPositioner.PlaceWindow(WinRect);
    end
    else if WindowMode = wcmMoveWindow then
    begin
      WinRect.TopLeft := NewPos;
      WindowPositioner.MoveWindow(NewPos);
    end;

    BringSwitchTargetNumberFormsToTop;
    if not MatchRect.IsEmpty then
      AddAnimation(
        TAlignIndicatorAnimation.Create(Self, MatchRect, WorkareaRect, MatchEdge),
        500, AlignIndicatorAniID);
  finally
    Snapper.Free;
    WindowPositioner.ExitWindow;
  end;
end;

procedure TMoverLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  function IsDirectionKey: Boolean;
  var
    D: TDirection;
  begin
    Result := WD.Types.IsDirectionKey(Key, D);
    if Result then
      MoveSizeWindow(D);
  end;

  function HandleSwitchTargetNumKey: Boolean;
  var
    SwitchTargetIndex : Integer;
    SwitchTargetWindow: TWindow;
    TargetWindow      : TWindow;
  begin
    Result :=
      IsSwitchTargetNumKey(Key, SwitchTargetIndex) and
      HasSwitchTarget(SwitchTargetIndex, SwitchTargetWindow) and
      HasTargetWindow(TargetWindow);

    if not Result then
      Exit;

    if TargetWindow.Handle <> SwitchTargetWindow.Handle then
    begin
      BringWindowToTop(SwitchTargetWindow.Handle);
      WD.WindowTools.BringWindowToTop(Application.MainFormHandle);
      BringSwitchTargetNumberFormsToTop;
    end;

    if ShowNumberForms or (ActiveSwitchTargetIndex = SwitchTargetIndex) then
      VirtualClickOnSwitchTargetNumberForm(SwitchTargetWindow.Handle, 300)
    else
      FClickOnSwitchTarget := SwitchTargetIndex >= 0;

    ActiveSwitchTargetIndex := SwitchTargetIndex;
  end;

begin
  if WindowsHandler.GetWindowList(wldDominaTargets).Count = 0 then
    Exit;

  if IsDirectionKey then
    Handled := True
  else if HandleSwitchTargetNumKey then
    Handled := True
  else if Key = vkReturn then
  begin
    if 
      (ActiveSwitchTargetIndex >= 0) and 
      Assigned(FSwitchTargets) and 
      (ActiveSwitchTargetIndex < FSwitchTargets.Count) then
      VirtualClickOnSwitchTargetNumberForm(FSwitchTargets[ActiveSwitchTargetIndex].Handle, 300);
  end
  else if IsWindowModeModifierKey(Key) then
    UpdateCurrentWindowMode;
end;

procedure TMoverLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin
  if IsWindowModeModifierKey(Key) then
    UpdateCurrentWindowMode;
  Handled := False;
end;

{ TAlignIndicatorAnimation }

constructor TAlignIndicatorAnimation.Create(Layer: TBaseLayer; const AlignTarget, Workarea: System.Types.TRect; Edge: TRectEdge);
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

procedure TAlignIndicatorAnimation.RenderSkia(Canvas: ISkCanvas);
var
  CurRectF: TRectF;
  Paint   : ISkPaint;
  R       : TRectF;
begin
  CurRectF := TRectF.Create(Layer.MonitorHandler.ScreenToClient(TAQ.EaseRect(FFrom, FTo, FProgress, etSinus)));
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.White;
  Canvas.DrawRect(CurRectF, Paint);
  Paint.Color := TAlphaColors.Black;
  R := CurRectF;
  R.Inflate(-2, -2);
  Canvas.DrawRect(R, Paint);
end;

{ TArrowIndicator }

procedure TArrowIndicator.DrawSkia(Canvas: ISkCanvas);
var
  ArrowSquare      : Single;
  ArrowSquare2     : Single;
  ArrowSquare3     : Single;
  ContainSquare    : Single;
  KeyDownDecorator : TKeyDecoratorSkiaProc;
  KeyLeftDecorator : TKeyDecoratorSkiaProc;
  KeyRightDecorator: TKeyDecoratorSkiaProc;
  KeyUpDecorator   : TKeyDecoratorSkiaProc;
  PaintRectF       : TRectF;
  RemainHeight     : Single;
  RemainWidth      : Single;
begin
  ArrowSquare := GetRefRectKeySquareSize(FRefRect);
  ArrowSquare2 := ArrowSquare * 2;
  ArrowSquare3 := ArrowSquare * 3;
  ContainSquare := ArrowSquare3;

  RemainWidth := (FRefRect.Width - ContainSquare) / 2;
  RemainHeight := (FRefRect.Height - ContainSquare) / 2;

  PaintRectF := TRectF.Create(
    FRefRect.Left + RemainWidth,
    FRefRect.Top + RemainHeight,
    FRefRect.Right - RemainWidth,
    FRefRect.Bottom - RemainHeight);

  if ShowTargetIndex and (TargetIndex >= 0) then
    KeyRenderManager.RenderSkia(
      Canvas,
      TargetIndex + vk0,
      TRectF.Create(
        PaintRectF.Left + ArrowSquare,
        PaintRectF.Top + ArrowSquare,
        PaintRectF.Left + ArrowSquare2,
        PaintRectF.Top + ArrowSquare2),
      ksFlat);

  case WindowMode of
    wcmGrowWindow:
    begin
      KeyUpDecorator := TKeyDecorators.TargetEdgeGrowTopIndicatorSkia;
      KeyRightDecorator := TKeyDecorators.TargetEdgeGrowRightIndicatorSkia;
      KeyDownDecorator := TKeyDecorators.TargetEdgeGrowBottomIndicatorSkia;
      KeyLeftDecorator := TKeyDecorators.TargetEdgeGrowLeftIndicatorSkia;
    end;
    wcmShrinkWindow:
    begin
      KeyUpDecorator := TKeyDecorators.TargetEdgeShrinkTopIndicatorSkia;
      KeyRightDecorator := TKeyDecorators.TargetEdgeShrinkRightIndicatorSkia;
      KeyDownDecorator := TKeyDecorators.TargetEdgeShrinkBottomIndicatorSkia;
      KeyLeftDecorator := TKeyDecorators.TargetEdgeShrinkLeftIndicatorSkia;
    end;
  else
    KeyUpDecorator := nil;
    KeyRightDecorator := nil;
    KeyDownDecorator := nil;
    KeyLeftDecorator := nil;
  end;

  KeyRenderManager.RenderSkia(
    Canvas,
    vkUp,
    TRectF.Create(
      PaintRectF.Left + ArrowSquare,
      PaintRectF.Top,
      PaintRectF.Left + ArrowSquare2,
      PaintRectF.Top + ArrowSquare),
    ksFlat,
    True,
    KeyUpDecorator);

  KeyRenderManager.RenderSkia(
    Canvas,
    vkRight,
    TRectF.Create(
      PaintRectF.Left + ArrowSquare2,
      PaintRectF.Top + ArrowSquare,
      PaintRectF.Left + ArrowSquare3,
      PaintRectF.Top + ArrowSquare2),
    ksFlat,
    True,
    KeyRightDecorator);

  KeyRenderManager.RenderSkia(
    Canvas,
    vkDown,
    TRectF.Create(
      PaintRectF.Left + ArrowSquare,
      PaintRectF.Top + ArrowSquare2,
      PaintRectF.Left + ArrowSquare2,
      PaintRectF.Top + ArrowSquare3),
    ksFlat,
    True,
    KeyDownDecorator);

  KeyRenderManager.RenderSkia(
    Canvas,
    vkLeft,
    TRectF.Create(
      PaintRectF.Left,
      PaintRectF.Top + ArrowSquare,
      PaintRectF.Left + ArrowSquare,
      PaintRectF.Top + ArrowSquare2),
    ksFlat,
    True,
    KeyLeftDecorator);
end;

function TArrowIndicator.HitTest(const Point: TPoint): Boolean;
var
  ArrowSquare: Integer;
  PaintRect  : TRect;
begin
  ArrowSquare := GetRefRectKeySquareSize(FRefRect);

  PaintRect.Left := FRefRect.Left + Round((FRefRect.Width - ArrowSquare * 3) / 2);
  PaintRect.Top := FRefRect.Top + Round((FRefRect.Height - ArrowSquare * 3) / 2);
  PaintRect.Width := ArrowSquare * 3;
  PaintRect.Height := ArrowSquare * 3;

  if not PaintRect.Contains(Point) then
    Exit(False);

  // Check individual arrows
  // Top
  if
    TRect.Create(
      PaintRect.Left + ArrowSquare,
      PaintRect.Top,
      PaintRect.Left + ArrowSquare * 2,
      PaintRect.Top + ArrowSquare).Contains(Point) then
    Exit(True);

  // Right
  if
    TRect.Create(
      PaintRect.Left + ArrowSquare * 2,
      PaintRect.Top + ArrowSquare,
      PaintRect.Left + ArrowSquare * 3,
      PaintRect.Top + ArrowSquare * 2).Contains(Point) then
    Exit(True);

  // Bottom
  if
    TRect.Create(
      PaintRect.Left + ArrowSquare,
      PaintRect.Top + ArrowSquare * 2,
      PaintRect.Left + ArrowSquare * 2,
      PaintRect.Top + ArrowSquare * 3).Contains(Point) then
    Exit(True);

  // Left
  if
    TRect.Create(
      PaintRect.Left,
      PaintRect.Top + ArrowSquare,
      PaintRect.Left + ArrowSquare,
      PaintRect.Top + ArrowSquare * 2).Contains(Point) then
    Exit(True);

  // Middle
  if
    ShowTargetIndex and
    (TargetIndex >= 0) and
    TRect.Create(
      PaintRect.Left + ArrowSquare,
      PaintRect.Top + ArrowSquare,
      PaintRect.Left + ArrowSquare * 2,
      PaintRect.Top + ArrowSquare * 2).Contains(Point) then
    Exit(True);

  Result := False;
end;

end.
