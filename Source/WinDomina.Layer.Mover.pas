unit WinDomina.Layer.Mover;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.D2D1,
  Vcl.Direct2D,

  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,

  WinDomina.Types,
  WinDomina.Types.Drawing,
  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools;

type
  TRectEdge = (reUnknown, reTop, reRight, reBottom, reLeft);

  TAnimationBase = class;
  TAnimationList = TObjectList<TAnimationBase>;

  TMoverLayer = class(TBaseLayer)
  private
    class var
    WindowMoveAniID: Integer;
    AlignIndicatorAniID: Integer;
  private
    FWindowEnumerator: TWindowEnumerator;
    FVisibleWindowList: WindowEnumerator.TWindowList;
    FAnimatedWindow: TWindow;
    FAnimations: TAnimationList;

    procedure UpdateVisibleWindowList;
    procedure AddAnimation(Animation: TAnimationBase; Duration, AnimationID: Integer);

  public
    class constructor Create;
    constructor Create; override;
    destructor Destroy; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    function HasMainContent(const DrawContext: IDrawContext;
      var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean; override;
    procedure RenderMainContent(const DrawContext: IDrawContext;
      const LayerParams: TD2D1LayerParameters); override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;
  end;

  TAnimationBase = class
  protected
    FProgress: Real;

  public
    procedure Render(const RenderTarget: ID2D1RenderTarget); virtual; abstract;
    property Progress: Real read FProgress write FProgress;
  end;

  TAlignIndicatorAnimation = class(TAnimationBase)
  private
    FFrom: TRect;
    FTo: TRect;
    FWhiteBrush: ID2D1SolidColorBrush;
    FBlackBrush: ID2D1SolidColorBrush;

  public
    constructor Create(const AlignTarget, Workarea: TRect; Edge: TRectEdge);
    procedure Render(const RenderTarget: ID2D1RenderTarget); override;
  end;

implementation

{ TMoverLayer }

class constructor TMoverLayer.Create;
begin
  WindowMoveAniID := TAQ.GetUniqueID;
  AlignIndicatorAniID := TAQ.GetUniqueID;
end;

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkM]);

  FWindowEnumerator := TWindowEnumerator.Create;
  FWindowEnumerator.RequiredWindowInfos := [wiRect];
  FWindowEnumerator.IncludeMask := WS_CAPTION or WS_VISIBLE;
  FWindowEnumerator.ExcludeMask := WS_DISABLED;
  FWindowEnumerator.VirtualDesktopFilter := True;
  FWindowEnumerator.HiddenWindowsFilter := True;
  FWindowEnumerator.OverlappedWindowsFilter := True;
  FWindowEnumerator.CloakedWindowsFilter := True;
  FWindowEnumerator.GetWindowRectFunction :=
    function(WindowHandle: HWND): TRect
    begin
      if not GetWindowRectDominaStyle(WindowHandle, Result) then
        Result := TRect.Empty;
    end;

  FAnimatedWindow := TWindow.Create;
  FAnimations := TAnimationList.Create(True);
end;

destructor TMoverLayer.Destroy;
begin
  FWindowEnumerator.Free;
  FVisibleWindowList.Free;
  FAnimatedWindow.Free;
  FAnimations.Free;

  inherited Destroy;
end;

procedure TMoverLayer.UpdateVisibleWindowList;
var
  LogWinHandle: HWND;
begin
  FVisibleWindowList.Free;
  FVisibleWindowList := FWindowEnumerator.Enumerate;
  // Aktuell dominiertes Fenster aus der Liste entfernen
  FVisibleWindowList.Remove(DominaWindows[0]);
  if Logging.HasWindowHandle(LogWinHandle) then
    FVisibleWindowList.Remove(LogWinHandle);
end;

procedure TMoverLayer.AddAnimation(Animation: TAnimationBase; Duration, AnimationID: Integer);
begin
  FAnimations.Add(Animation);

  Take(Animation)
    .EachAnimation(Duration,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        TAnimationBase(O).Progress := AQ.CurrentInterval.Progress;
        InvalidateMainContent;
        Result := True;
      end,
      function(AQ: TAQ; O: TObject): Boolean
      begin
        AQ.Remove(O);
        FAnimations.Remove(TAnimationBase(O));
        InvalidateMainContent;
        Result := True;
      end, AnimationID);
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TMoverLayer.EnterLayer');
end;

procedure TMoverLayer.ExitLayer;
begin
  AddLog('TMoverLayer.ExitLayer');
  inherited ExitLayer;
end;

function TMoverLayer.HasMainContent(const DrawContext: IDrawContext;
  var LayerParams: TD2D1LayerParameters; out Layer: ID2D1Layer): Boolean;
begin
  Result := IsLayerActive;
end;

procedure TMoverLayer.RenderMainContent(const DrawContext: IDrawContext;
  const LayerParams: TD2D1LayerParameters);
var
  Animation: TAnimationBase;
  RT: ID2D1RenderTarget;
begin
  if FAnimations.Count > 0 then
  begin
    RT := DrawContext.RenderTarget;
    for Animation in FAnimations do
      Animation.Render(RT);
  end;
end;

procedure TMoverLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  procedure MoveSizeWindow(Direction: TDirection);
  var
    Window: THandle;
    WinRect, MatchRect, TestRect, WorkareaRect: TRect;
    TestWin: TWindow;
    NewPos: TPoint;
    MatchEdge: TRectEdge;

    // Sagt aus, ob der absolute Unterschied zwischen den beiden Parametern
    // eine Mindestdifferenz erfüllt
    function NoSnap(A, B: Integer): Boolean;
    begin
      Result := Abs(A - B) >= 5;
    end;

    function Snap(A, B: Integer): Boolean;
    begin
      Result := Abs(A - B) < 5;
    end;

    procedure NoXEdgeMatch;
    var
      Center: Integer;
    begin
      Center := (WorkareaRect.Width - WinRect.Width) div 2;
      if NoSnap(WinRect.Left, Center) and
        (
          ((Direction = dirLeft) and (WinRect.Left > Center)) or
          ((Direction = dirRight) and (WinRect.Left < Center))
        ) then
        NewPos.X := Center;
    end;

    procedure NoYEdgeMatch;
    var
      Center: Integer;
    begin
      Center := (WorkareaRect.Height - WinRect.Height) div 2;
      if NoSnap(WinRect.Top, Center) and
        (
          ((Direction = dirUp) and (WinRect.Top > Center)) or
          ((Direction = dirDown) and (WinRect.Top < Center))
        ) then
        NewPos.Y := Center;
    end;

  begin
    if DominaWindows.Count = 0 then
      Exit;

    // Sollte die Animation noch laufen, so muss sie abgebrochen werden
    Take(FAnimatedWindow)
      .FinishAnimations(WindowMoveAniID);

    Window := DominaWindows[0];
    GetWindowRect(Window, WinRect);
    WorkareaRect := GetWorkareaRect(WinRect);
    GetWindowRectDominaStyle(Window, WinRect);

    UpdateVisibleWindowList;
    NewPos := TPoint.Zero;
    MatchRect := TRect.Empty;
    MatchEdge := reUnknown;

    if Direction = dirLeft then
    begin
      NewPos.X := WorkareaRect.Left;
      NewPos.Y := WinRect.Top;

      for TestWin in FVisibleWindowList do
      begin
        TestRect := TestWin.Rect;
        // Rechte Kante
        if (TestRect.Right >= WorkareaRect.Left) and (TestRect.Right < WinRect.Left) and
          (NewPos.X < TestRect.Right) and NoSnap(TestRect.Right, WinRect.Left) then
        begin
          NewPos.X := TestRect.Right;
          MatchEdge := reRight;
          MatchRect := TestRect;
        end
        // Linke Kante
        else if (TestRect.Left >= WorkareaRect.Left) and (TestRect.Left < WinRect.Left) and
          (NewPos.X < TestRect.Left) and NoSnap(TestRect.Left, WinRect.Left) then
        begin
          NewPos.X := TestRect.Left;
          MatchEdge := reLeft;
          MatchRect := TestRect;
        end;
      end;
    end
    else if Direction = dirRight then
    begin
      NewPos.X := WorkareaRect.Right - WinRect.Width;
      NewPos.Y := WinRect.Top;

      for TestWin in FVisibleWindowList do
      begin
        TestRect := TestWin.Rect;
        // Linke Kante
        if (TestRect.Left <= WorkareaRect.Right) and (TestRect.Left > WinRect.Right) and
          (NewPos.X > (TestRect.Left - WinRect.Width)) and
          NoSnap(TestRect.Left, WinRect.Right) then
        begin
          NewPos.X := TestRect.Left - WinRect.Width;
          MatchEdge := reLeft;
          MatchRect := TestRect;
        end
        // Rechte Kante
        else if (TestRect.Right <= WorkareaRect.Right) and (TestRect.Right > WinRect.Right) and
         (NewPos.X > (TestRect.Right - WinRect.Width)) and
         NoSnap(TestRect.Right, WinRect.Right) then
        begin
          NewPos.X := TestRect.Right - WinRect.Width;
          MatchEdge := reRight;
          MatchRect := TestRect;
        end;
      end;
    end
    else if Direction = DirUp then
    begin
      NewPos.X := WinRect.Left;
      NewPos.Y := WorkareaRect.Top;

      for TestWin in FVisibleWindowList do
      begin
        TestRect := TestWin.Rect;
        // Untere Kante
        if (TestRect.Bottom >= WorkareaRect.Top) and (TestRect.Bottom < WinRect.Top) and
          (NewPos.Y < TestRect.Bottom) and NoSnap(TestRect.Bottom, WinRect.Top) then
        begin
          NewPos.Y := TestRect.Bottom;
          MatchEdge := reBottom;
          MatchRect := TestRect;
        end
        // Obere Kante
        else if (TestRect.Top >= WorkareaRect.Top) and (TestRect.Top < WinRect.Top) and
          (NewPos.Y < TestRect.Top) and NoSnap(TestRect.Top, WinRect.Top) then
        begin
          NewPos.Y := TestRect.Top;
          MatchEdge := reTop;
          MatchRect := TestRect;
        end;
      end;
    end
    else if Direction = dirDown then
    begin
      NewPos.X := WinRect.Left;
      NewPos.Y := WorkareaRect.Bottom - WinRect.Height;

      for TestWin in FVisibleWindowList do
      begin
        TestRect := TestWin.Rect;
        // Obere Kante
        if (TestRect.Top <= WorkareaRect.Bottom) and (WinRect.Bottom < TestRect.Top) and
          (NewPos.Y > (TestRect.Top - WinRect.Height)) and
          NoSnap(WinRect.Bottom, TestRect.Top) then
        begin
          NewPos.Y := TestRect.Top - WinRect.Height;
          MatchEdge := reTop;
          MatchRect := TestRect;
        end
        // Untere Kante
        else if (TestRect.Bottom <= WorkareaRect.Bottom) and (WinRect.Bottom < TestRect.Bottom) and
         (NewPos.Y > (TestRect.Bottom - WinRect.Height)) and
         NoSnap(WinRect.Bottom, TestRect.Bottom) then
        begin
          NewPos.Y := TestRect.Bottom - WinRect.Height;
          MatchEdge := reBottom;
          MatchRect := TestRect;
        end;
      end;
    end
    else
      Exit;

    // Zentrierungen, wenn es keine Kollisionskanten gibt
    if MatchEdge = reUnknown then
      case Direction of
        dirUp,
        dirDown:
          NoYEdgeMatch;
        dirRight,
        dirLeft:
          NoXEdgeMatch;
      end;

    FAnimatedWindow.Handle := Window;
    FAnimatedWindow.Rect := WinRect; // Die ursprüngliche Postion des Fensters

    // WinRect enthält ab hier die neue Position
    WinRect.TopLeft := NewPos;

    Take(FAnimatedWindow)
      .Plugin<TAQPSystemTypesAnimations>
      .RectAnimation(WinRect,
        function(RefObject: TObject): TRect
        begin
          Result := TWindow(RefObject).Rect;
        end,
        procedure(RefObject: TObject; const NewRect: TRect)
        begin
          SetWindowPosDominaStyle(TWindow(RefObject).Handle, 0, NewRect, SWP_NOZORDER or SWP_NOSIZE);
        end,
        250, WindowMoveAniID, TAQ.Ease(TEaseType.etSinus));

    if not MatchRect.IsEmpty then
      AddAnimation(TAlignIndicatorAnimation.Create(MatchRect, WorkareaRect, MatchEdge), 500, AlignIndicatorAniID);
  end;

var
  Direction: TDirection;
begin
  Direction := dirUnknown;

  case Key of
    vkLeft:
      Direction := dirLeft;
    vkRight:
      Direction := dirRight;
    vkUp:
      Direction := dirUp;
    vkDown:
      Direction := dirDown;
  end;

  if Direction <> dirUnknown then
  begin
    MoveSizeWindow(Direction);
    Handled := True;
  end;
end;

procedure TMoverLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

{ TAlignIndicatorAnimation }

constructor TAlignIndicatorAnimation.Create(const AlignTarget, Workarea: TRect; Edge: TRectEdge);
const
  XMargin = 4;
  YMargin = 4;
begin
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

procedure TAlignIndicatorAnimation.Render(const RenderTarget: ID2D1RenderTarget);
var
  CurRect: TRect;
begin
  if not Assigned(FWhiteBrush) then
    RenderTarget.CreateSolidColorBrush(D2D1ColorF(TColors.White), nil, FWhiteBrush);
  if not Assigned(FBlackBrush) then
    RenderTarget.CreateSolidColorBrush(D2D1ColorF(TColors.Black), nil, FBlackBrush);

  CurRect := TAQ.EaseRect(FFrom, FTo, FProgress, etSinus);
  RenderTarget.FillRectangle(CurRect, FWhiteBrush);
  CurRect.Inflate(-2, -2);
  RenderTarget.FillRectangle(CurRect, FBlackBrush);
end;

end.
