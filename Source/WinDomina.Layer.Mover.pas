unit WinDomina.Layer.Mover;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Generics.Collections,
  System.Contnrs,
  Winapi.Windows,
  Winapi.D2D1,
  Vcl.Direct2D,
  Vcl.Forms,

  WindowEnumerator,
  AnyiQuack,
  AQPSystemTypesAnimations,

  WinDomina.Types,
  WinDomina.Types.Drawing,
  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools,
  WinDomina.WindowMatchSnap;

type
  TAnimationBase = class;
  TAnimationList = TObjectList<TAnimationBase>;

  TMoverLayer = class(TBaseLayer)
  private
    class var
    WindowMoveAniID: Integer;
    AlignIndicatorAniID: Integer;
  private
    FVisibleWindowList: TWindowList;
    FDominaTargetsWindowList: TWindowList;
    FAnimatedWindow: TWindow;
    FAnimations: TAnimationList;

    procedure UpdateVisibleWindowList;
    procedure UpdateDominaTargetsWindowList;
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
    FLayer: TBaseLayer;

  public
    constructor Create(Layer: TBaseLayer);

    procedure Render(const RenderTarget: ID2D1RenderTarget); virtual; abstract;
    property Progress: Real read FProgress write FProgress;
    property Layer: TBaseLayer read FLayer;
  end;

  TAlignIndicatorAnimation = class(TAnimationBase)
  private
    FFrom: TRect;
    FTo: TRect;
    FWhiteBrush: ID2D1SolidColorBrush;
    FBlackBrush: ID2D1SolidColorBrush;

  public
    constructor Create(Layer: TBaseLayer; const AlignTarget, Workarea: TRect; Edge: TRectEdge);
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
  FAnimatedWindow := TWindow.Create;
  FAnimations := TAnimationList.Create(True);
end;

destructor TMoverLayer.Destroy;
begin
  FVisibleWindowList.Free;
  FDominaTargetsWindowList.Free;
  FAnimatedWindow.Free;
  FAnimations.Free;

  inherited Destroy;
end;

procedure TMoverLayer.UpdateVisibleWindowList;
var
  LogWinHandle: HWND;
begin
  FVisibleWindowList.Free;
  FVisibleWindowList := WindowsHandler.CreateWindowList(wldAlignTargets);
  // Aktuell dominiertes Fenster aus der Liste entfernen
  FVisibleWindowList.Remove(FDominaTargetsWindowList[0].Handle);
  if Logging.HasWindowHandle(LogWinHandle) then
    FVisibleWindowList.Remove(LogWinHandle);
end;

procedure TMoverLayer.UpdateDominaTargetsWindowList;
begin
  FDominaTargetsWindowList.Free;
  FDominaTargetsWindowList := WindowsHandler.CreateWindowList(wldDominaTargets);
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
  UpdateDominaTargetsWindowList;
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
    UpdateDominaTargetsWindowList;
    if FDominaTargetsWindowList.Count = 0 then
      Exit;

    // Sollte die Animation noch laufen, so muss sie abgebrochen werden
    Take(FAnimatedWindow)
      .FinishAnimations(WindowMoveAniID);

    Window := FDominaTargetsWindowList[0].Handle;
    GetWindowRect(Window, WinRect);
    WorkareaRect := GetWorkareaRect(WinRect);
    GetWindowRectDominaStyle(Window, WinRect);

    UpdateVisibleWindowList;
    NewPos := TPoint.Zero;
    MatchRect := TRect.Empty;
    MatchEdge := reUnknown;

    Snapper := TWindowMatchSnap.Create(WinRect, WorkareaRect, FVisibleWindowList);
    try
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
      end
      // ...dann suchen wir nach einer horizontalen...
      else if (Direction in [dirLeft, dirRight]) and
        Snapper.HasWorkAreaCenterMatchHorizontal(Direction, NewPos) then
      begin
        MatchRect := WorkareaRect;
        Dec(MatchRect.Right, MatchRect.Width div 2);
        IndentMatchRect;
        MatchEdge := reRight;
      end
      // ...oder vertikalen Mitte der Arbeitsfläche...
      else if (Direction in [dirUp, dirDown]) and
        Snapper.HasWorkAreaCenterMatchVertical(Direction, NewPos) then
      begin
        MatchRect := WorkareaRect;
        Dec(MatchRect.Bottom, MatchRect.Height div 2);
        IndentMatchRect;
        MatchEdge := reBottom;
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
    finally
      Snapper.Free;
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
      AddAnimation(TAlignIndicatorAnimation.Create(Self, MatchRect, WorkareaRect, MatchEdge), 500,
        AlignIndicatorAniID);
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

{ TAnimationBase }

constructor TAnimationBase.Create(Layer: TBaseLayer);
begin
  FLayer := Layer;
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

procedure TAlignIndicatorAnimation.Render(const RenderTarget: ID2D1RenderTarget);
var
  CurRect: TRect;
begin
  if not Assigned(FWhiteBrush) then
    RenderTarget.CreateSolidColorBrush(D2D1ColorF(TColors.White), nil, FWhiteBrush);
  if not Assigned(FBlackBrush) then
    RenderTarget.CreateSolidColorBrush(D2D1ColorF(TColors.Black), nil, FBlackBrush);

  CurRect := Layer.MonitorHandler.ScreenToClient(
    TAQ.EaseRect(FFrom, FTo, FProgress, etSinus));
  RenderTarget.FillRectangle(CurRect, FWhiteBrush);
  CurRect.Inflate(-2, -2);
  RenderTarget.FillRectangle(CurRect, FBlackBrush);
end;

end.
