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
begin
  MatchEdge := reUnknown;
  NewRefRectPos.X := FWorkArea.Left;
  NewRefRectPos.Y := FRefRect.Top;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Rechte Kante
    if (TestRect.Right >= FWorkArea.Left) and (TestRect.Right < FRefRect.Left) and
      (NewRefRectPos.X < TestRect.Right) and NoSnap(TestRect.Right, FRefRect.Left) then
    begin
      NewRefRectPos.X := TestRect.Right;
      MatchEdge := reRight;
      MatchWindow := TestWin;
    end
    // Linke Kante
    else if (TestRect.Left >= FWorkArea.Left) and (TestRect.Left < FRefRect.Left) and
      (NewRefRectPos.X < TestRect.Left) and NoSnap(TestRect.Left, FRefRect.Left) then
    begin
      NewRefRectPos.X := TestRect.Left;
      MatchEdge := reLeft;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
end;

function TWindowMatchSnap.HasMatchSnapWindowRight(out MatchWindow: TWindow;
  out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
begin
  MatchEdge := reUnknown;
  NewRefRectPos.X := FWorkArea.Right - FRefRect.Width;
  NewRefRectPos.Y := FRefRect.Top;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Linke Kante
    if (TestRect.Left <= FWorkarea.Right) and (TestRect.Left > FRefRect.Right) and
      (NewRefRectPos.X > (TestRect.Left - FRefRect.Width)) and
      NoSnap(TestRect.Left, FRefRect.Right) then
    begin
      NewRefRectPos.X := TestRect.Left - FRefRect.Width;
      MatchEdge := reLeft;
      MatchWindow := TestWin;
    end
    // Rechte Kante
    else if (TestRect.Right <= FWorkarea.Right) and (TestRect.Right > FRefRect.Right) and
     (NewRefRectPos.X > (TestRect.Right - FRefRect.Width)) and
     NoSnap(TestRect.Right, FRefRect.Right) then
    begin
      NewRefRectPos.X := TestRect.Right - FRefRect.Width;
      MatchEdge := reRight;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
end;

function TWindowMatchSnap.HasMatchSnapWindowTop(out MatchWindow: TWindow; out MatchEdge: TRectEdge;
  out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
begin
  MatchEdge := reUnknown;
  NewRefRectPos.X := FRefRect.Left;
  NewRefRectPos.Y := FWorkarea.Top;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Untere Kante
    if (TestRect.Bottom >= FWorkarea.Top) and (TestRect.Bottom < FRefRect.Top) and
      (NewRefRectPos.Y < TestRect.Bottom) and NoSnap(TestRect.Bottom, FRefRect.Top) then
    begin
      NewRefRectPos.Y := TestRect.Bottom;
      MatchEdge := reBottom;
      MatchWindow := TestWin;
    end
    // Obere Kante
    else if (TestRect.Top >= FWorkarea.Top) and (TestRect.Top < FRefRect.Top) and
      (NewRefRectPos.Y < TestRect.Top) and NoSnap(TestRect.Top, FRefRect.Top) then
    begin
      NewRefRectPos.Y := TestRect.Top;
      MatchEdge := reTop;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
end;

function TWindowMatchSnap.HasMatchSnapWindowBottom(out MatchWindow: TWindow;
  out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TestWin: TWindow;
  TestRect: TRect;
begin
  MatchEdge := reUnknown;
  NewRefRectPos.X := FRefRect.Left;
  NewRefRectPos.Y := FWorkarea.Bottom - FRefRect.Height;

  for TestWin in FWindowList do
  begin
    TestRect := TestWin.Rect;
    // Obere Kante
    if (TestRect.Top <= FWorkarea.Bottom) and (FRefRect.Bottom < TestRect.Top) and
      (NewRefRectPos.Y > (TestRect.Top - FRefRect.Height)) and
      NoSnap(FRefRect.Bottom, TestRect.Top) then
    begin
      NewRefRectPos.Y := TestRect.Top - FRefRect.Height;
      MatchEdge := reTop;
      MatchWindow := TestWin;
    end
    // Untere Kante
    else if (TestRect.Bottom <= FWorkarea.Bottom) and (FRefRect.Bottom < TestRect.Bottom) and
     (NewRefRectPos.Y > (TestRect.Bottom - FRefRect.Height)) and
     NoSnap(FRefRect.Bottom, TestRect.Bottom) then
    begin
      NewRefRectPos.Y := TestRect.Bottom - FRefRect.Height;
      MatchEdge := reBottom;
      MatchWindow := TestWin;
    end;
  end;

  Result := MatchEdge > reUnknown;
end;

end.
