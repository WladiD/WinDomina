unit WinDomina.WindowMatchSnap;

interface

uses
  System.Types,
  System.Classes,
  System.SysUtils,

  WinDomina.Types,
  WinDomina.WindowTools,
  WindowEnumerator;


type
  TWindowMatchSnap = class
  private
    FRefRect: TRect;
    FWorkArea: TRect;
    FWindowList: TWindowList;

    function GetRefRectDefaultPositionLeft: TPoint;
    function GetRefRectDefaultPositionRight: TPoint;
    function GetRefRectDefaultPositionTop: TPoint;
    function GetRefRectDefaultPositionBottom: TPoint;

  public
    constructor Create(const RefRect, WorkArea: TRect; WindowList: TWindowList);

    function HasMatchSnapWindowLeft(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasMatchSnapWindowRight(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasMatchSnapWindowTop(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasMatchSnapWindowBottom(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;

    function HasWorkAreaEdgeMatchLeft(out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasWorkAreaEdgeMatchRight(out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasWorkAreaEdgeMatchTop(out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;
    function HasWorkAreaEdgeMatchBottom(out MatchEdge: TRectEdge;
      out NewRefRectPos: TPoint): Boolean;

    function HasWorkAreaCenterMatchHorizontal(Direction: TDirection;
      out NewRefRectPos: TPoint): Boolean;
    function HasWorkAreaCenterMatchVertical(Direction: TDirection;
      out NewRefRectPos: TPoint): Boolean;
  end;

implementation

{ TWindowMatchSnap }

constructor TWindowMatchSnap.Create(const RefRect, WorkArea: TRect; WindowList: TWindowList);
begin
  FRefRect := RefRect;
  FWorkArea := WorkArea;
  FWindowList := WindowList;
end;

function TWindowMatchSnap.HasMatchSnapWindowLeft(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
  TempPos: TPoint;
begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionLeft;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Rechte Kante
    if (TestRect.Right >= FWorkArea.Left) and (TestRect.Right < FRefRect.Left) and
      (TempPos.X < TestRect.Right) and NoSnap(TestRect.Right, FRefRect.Left) then
    begin
      TempPos.X := TestRect.Right;
      MatchEdge := reRight;
      MatchWindow := TestWin;
    end
    // Linke Kante
    else if (TestRect.Left >= FWorkArea.Left) and (TestRect.Left < FRefRect.Left) and
      (TempPos.X < TestRect.Left) and NoSnap(TestRect.Left, FRefRect.Left) then
    begin
      TempPos.X := TestRect.Left;
      MatchEdge := reLeft;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
  if Result then
    NewRefRectPos := TempPos;
end;

function TWindowMatchSnap.HasMatchSnapWindowRight(out MatchWindow: TWindow;
  out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
  TempPos: TPoint;
begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionRight;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Linke Kante
    if (TestRect.Left <= FWorkArea.Right) and (TestRect.Left > FRefRect.Right) and
      (TempPos.X > (TestRect.Left - FRefRect.Width)) and
      NoSnap(TestRect.Left, FRefRect.Right) then
    begin
      TempPos.X := TestRect.Left - FRefRect.Width;
      MatchEdge := reLeft;
      MatchWindow := TestWin;
    end
    // Rechte Kante
    else if (TestRect.Right <= FWorkArea.Right) and (TestRect.Right > FRefRect.Right) and
     (TempPos.X > (TestRect.Right - FRefRect.Width)) and
     NoSnap(TestRect.Right, FRefRect.Right) then
    begin
      TempPos.X := TestRect.Right - FRefRect.Width;
      MatchEdge := reRight;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
  if Result then
    NewRefRectPos := TempPos;
end;

function TWindowMatchSnap.HasMatchSnapWindowTop(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
  TempPos: TPoint;
begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionTop;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Untere Kante
    if (TestRect.Bottom >= FWorkArea.Top) and (TestRect.Bottom < FRefRect.Top) and
      (TempPos.Y < TestRect.Bottom) and NoSnap(TestRect.Bottom, FRefRect.Top) then
    begin
      TempPos.Y := TestRect.Bottom;
      MatchEdge := reBottom;
      MatchWindow := TestWin;
    end
    // Obere Kante
    else if (TestRect.Top >= FWorkArea.Top) and (TestRect.Top < FRefRect.Top) and
      (TempPos.Y < TestRect.Top) and NoSnap(TestRect.Top, FRefRect.Top) then
    begin
      TempPos.Y := TestRect.Top;
      MatchEdge := reTop;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
  if Result then
    NewRefRectPos := TempPos;
end;

function TWindowMatchSnap.HasMatchSnapWindowBottom(out MatchWindow: TWindow;
  out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
  TempPos: TPoint;
begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionBottom;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Obere Kante
    if (TestRect.Top <= FWorkArea.Bottom) and (FRefRect.Bottom < TestRect.Top) and
      (TempPos.Y > (TestRect.Top - FRefRect.Height)) and
      NoSnap(FRefRect.Bottom, TestRect.Top) then
    begin
      TempPos.Y := TestRect.Top - FRefRect.Height;
      MatchEdge := reTop;
      MatchWindow := TestWin;
    end
    // Untere Kante
    else if (TestRect.Bottom <= FWorkArea.Bottom) and (FRefRect.Bottom < TestRect.Bottom) and
     (TempPos.Y > (TestRect.Bottom - FRefRect.Height)) and
     NoSnap(FRefRect.Bottom, TestRect.Bottom) then
    begin
      TempPos.Y := TestRect.Bottom - FRefRect.Height;
      MatchEdge := reBottom;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
  if Result then
    NewRefRectPos := TempPos;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchLeft(out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionLeft;
  Result := TempPos <> FRefRect.Location;
  if Result then
  begin
    MatchEdge := reLeft;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchRight(out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionRight;
  Result := TempPos <> FRefRect.Location;
  if Result then
  begin
    MatchEdge := reRight;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchTop(out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionTop;
  Result := TempPos <> FRefRect.Location;
  if Result then
  begin
    MatchEdge := reTop;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchBottom(out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionBottom;
  Result := TempPos <> FRefRect.Location;
  if Result then
  begin
    MatchEdge := reBottom;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaCenterMatchHorizontal(Direction: TDirection;
  out NewRefRectPos: TPoint): Boolean;
var
  Center: Integer;
begin
  Center := FWorkArea.Left + ((FWorkArea.Width - FRefRect.Width) div 2);
  Result := NoSnap(FRefRect.Left, Center) and
    (
      ((Direction = dirLeft) and (FRefRect.Left > Center)) or
      ((Direction = dirRight) and (FRefRect.Left < Center))
    );

  if Result then
  begin
    NewRefRectPos := FRefRect.Location;
    NewRefRectPos.X := Center;
  end;
end;

function TWindowMatchSnap.HasWorkAreaCenterMatchVertical(Direction: TDirection;
  out NewRefRectPos: TPoint): Boolean;
var
  Center: Integer;
begin
  Center := FWorkArea.Top + ((FWorkArea.Height - FRefRect.Height) div 2);
  Result := NoSnap(FRefRect.Top, Center) and
    (
      ((Direction = dirUp) and (FRefRect.Top > Center)) or
      ((Direction = dirDown) and (FRefRect.Top < Center))
    );
  if Result then
  begin
    NewRefRectPos := FRefRect.Location;
    NewRefRectPos.Y := Center;
  end;
end;

function TWindowMatchSnap.GetRefRectDefaultPositionLeft: TPoint;
begin
  Result := Point(FWorkArea.Left, FRefRect.Top);
end;

function TWindowMatchSnap.GetRefRectDefaultPositionRight: TPoint;
begin
  Result := Point(FWorkArea.Right - FRefRect.Width, FRefRect.Top);
end;

function TWindowMatchSnap.GetRefRectDefaultPositionTop: TPoint;
begin
  Result := Point(FRefRect.Left, FWorkArea.Top);
end;

function TWindowMatchSnap.GetRefRectDefaultPositionBottom: TPoint;
begin
  Result := Point(FRefRect.Left, FWorkArea.Bottom - FRefRect.Height);
end;

end.
