// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.WindowMatchSnap;

interface

uses

  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,

  WindowEnumerator,

  WD.Types,
  WD.WindowTools;

type

  TWindowMatchSnap = class
  private
    // WAC = WorkAreaCenter
    FPhantomWACBottom    : TWindow;
    FPhantomWACLeft      : TWindow;
    FPhantomWACRight     : TWindow;
    FPhantomWACTop       : TWindow;
    FPhantomWindowsHolder: TWindowList;
    FRefRect             : TRect;
    FWindowList          : TWindowList;
    FWorkArea            : TRect;
    function GetRefRectDefaultPositionLeft: TPoint;
    function GetRefRectDefaultPositionRight: TPoint;
    function GetRefRectDefaultPositionTop: TPoint;
    function GetRefRectDefaultPositionBottom: TPoint;
    function CreatePhantomWindow: TWindow;
  public
    constructor Create(const RefRect, WorkArea: TRect; WindowList: TWindowList);
    destructor Destroy; override;

    procedure AddPhantomWorkareaCenterWindows;
    function  HasMatchSnapWindowBottom(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasMatchSnapWindowLeft(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasMatchSnapWindowRight(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasMatchSnapWindowTop(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasWorkAreaEdgeMatchBottom(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasWorkAreaEdgeMatchLeft(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasWorkAreaEdgeMatchRight(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  HasWorkAreaEdgeMatchTop(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
    function  IsPhantomWindow(Window: TWindow): Boolean;
  end;

implementation

const
  PhantomWindowClassName = 'TWindowMatchSnap_PHANTOM';

{ TWindowMatchSnap }

constructor TWindowMatchSnap.Create(const RefRect, WorkArea: TRect; WindowList: TWindowList);
begin
  FRefRect := RefRect;
  FWorkArea := WorkArea;
  FWindowList := WindowList;
  FPhantomWindowsHolder := TWindowList.Create(True);

  FPhantomWACLeft := CreatePhantomWindow;
  FPhantomWACTop := CreatePhantomWindow;
  FPhantomWACRight := CreatePhantomWindow;
  FPhantomWACBottom := CreatePhantomWindow;
end;

destructor TWindowMatchSnap.Destroy;
begin
  FPhantomWindowsHolder.Free;
  inherited Destroy;
end;

function TWindowMatchSnap.CreatePhantomWindow: TWindow;
begin
  Result := TWindow.Create;
  Result.ClassName := PhantomWindowClassName;
  FPhantomWindowsHolder.Add(Result);
end;

procedure TWindowMatchSnap.AddPhantomWorkareaCenterWindows;

  procedure PassToWindowList(PhantomWindow: TWindow);
  begin
    FWindowList.Add(PhantomWindow);
    FPhantomWindowsHolder.Extract(PhantomWindow);
  end;

var
  R           : PRect;
  RemainBottom: Integer;
  RemainDiv   : UInt64;
  RemainLeft  : Integer;
  RemainRight : Integer;
  RemainTop   : Integer;
  RemainX     : UInt64;
  RemainY     : UInt64;
begin
  DivMod(FWorkArea.Width - FRefRect.Width, 2, RemainX, RemainDiv);
  RemainLeft := RemainX + RemainDiv;
  RemainRight := RemainX;

  DivMod(FWorkArea.Height - FRefRect.Height, 2, RemainY, RemainDiv);
  RemainTop := RemainY + RemainDiv;
  RemainBottom := RemainY;

  // Phantomfenster linke Seite
  R := @FPhantomWACLeft.Rect;
  R.Left := FWorkArea.Left;
  R.Top := FWorkArea.Top + RemainTop;
  R.Right := R.Left + RemainLeft;
  R.Bottom := R.Top + FRefRect.Height;
  PassToWindowList(FPhantomWACLeft);

  // Phantomfenster rechte Seite
  R := @FPhantomWACRight.Rect;
  R.Left := FWorkArea.Right - RemainRight;
  R.Top := FWorkArea.Top + RemainTop;
  R.Right := FWorkArea.Right;
  R.Bottom := R.Top + FRefRect.Height;
  PassToWindowList(FPhantomWACRight);

  // Phantomfenster obere Seite
  R := @FPhantomWACTop.Rect;
  R.Left := FWorkArea.Left + RemainLeft;
  R.Top := FWorkArea.Top;
  R.Right := FWorkArea.Right - RemainRight;
  R.Bottom := R.Top + RemainTop;
  PassToWindowList(FPhantomWACTop);

  // Phantomfenster untere Seite
  R := @FPhantomWACBottom.Rect;
  R.Left := FWorkArea.Left + RemainLeft;
  R.Top := FWorkArea.Bottom - RemainBottom;
  R.Right := FWorkArea.Right - RemainRight;
  R.Bottom := FWorkArea.Bottom;
  PassToWindowList(FPhantomWACBottom);
end;

function TWindowMatchSnap.IsPhantomWindow(Window: TWindow): Boolean;
begin
  Result := Window.ClassName = PhantomWindowClassName;
end;

function TWindowMatchSnap.HasMatchSnapWindowLeft(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos : TPoint;
  TestRect: TRect;
  TestWin : TWindow;

  function IsWindowEdgeMatchAllowed: Boolean;
  begin
    Result := not IsPhantomWindow(TestWin) or (TestWin = FPhantomWACLeft);
  end;

begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionLeft;

  for TestWin in FWindowList do
  begin
    if not IsWindowEdgeMatchAllowed then
      Continue;

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
  begin
    // Wir erstellen einen weiteren Klon des Phantomfensters, welches dann eine andere Kante besitzt
    if MatchWindow = FPhantomWACLeft then
    begin
      MatchWindow := CreatePhantomWindow;
      MatchWindow.Assign(FPhantomWACLeft);
      Inc(MatchWindow.Rect.Right, FRefRect.Width div 2);
    end;

    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasMatchSnapWindowRight(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos : TPoint;
  TestRect: TRect;
  TestWin : TWindow;

  function IsWindowEdgeMatchAllowed: Boolean;
  begin
    Result := not IsPhantomWindow(TestWin) or (TestWin = FPhantomWACRight);
  end;

begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionRight;

  for TestWin in FWindowList do
  begin
    if not IsWindowEdgeMatchAllowed then
      Continue;

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
  begin
    // Wir erstellen einen weiteren Klon des Phantomfensters, welches dann eine andere Kante besitzt
    if MatchWindow = FPhantomWACRight then
    begin
      MatchWindow := CreatePhantomWindow;
      MatchWindow.Assign(FPhantomWACRight);
      Dec(MatchWindow.Rect.Left, FRefRect.Width div 2);
    end;

    NewRefRectPos := TempPos;
  end
end;

function TWindowMatchSnap.HasMatchSnapWindowTop(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos : TPoint;
  TestRect: TRect;
  TestWin : TWindow;

  function IsWindowEdgeMatchAllowed: Boolean;
  begin
    Result := not IsPhantomWindow(TestWin) or (TestWin = FPhantomWACTop);
  end;

begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionTop;

  for TestWin in FWindowList do
  begin
    if not IsWindowEdgeMatchAllowed then
      Continue;

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
  begin
    // Wir erstellen einen weiteren Klon des Phantomfensters, welches dann eine andere Kante besitzt
    if MatchWindow = FPhantomWACTop then
    begin
      MatchWindow := CreatePhantomWindow;
      MatchWindow.Assign(FPhantomWACTop);
      Inc(MatchWindow.Rect.Bottom, FRefRect.Height div 2);
    end;

    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasMatchSnapWindowBottom(out MatchWindow: TWindow; out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos : TPoint;
  TestRect: TRect;
  TestWin : TWindow;

  function IsWindowEdgeMatchAllowed: Boolean;
  begin
    Result := not IsPhantomWindow(TestWin) or (TestWin = FPhantomWACBottom);
  end;

begin
  MatchEdge := reUnknown;
  TempPos := GetRefRectDefaultPositionBottom;

  for TestWin in FWindowList do
  begin
    if not IsWindowEdgeMatchAllowed then
      Continue;

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
  begin
    // Wir erstellen einen weiteren Klon des Phantomfensters, welches dann eine andere Kante besitzt
    if MatchWindow = FPhantomWACBottom then
    begin
      MatchWindow := CreatePhantomWindow;
      MatchWindow.Assign(FPhantomWACBottom);
      Dec(MatchWindow.Rect.Top, FRefRect.Height div 2);
    end;

    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchLeft(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionLeft;
  Result := NoSnap(TempPos.X, FRefRect.Left);
  if Result then
  begin
    MatchEdge := reLeft;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchRight(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionRight;
  Result := NoSnap(TempPos.X, FRefRect.Left);
  if Result then
  begin
    MatchEdge := reRight;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchTop(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionTop;
  Result := NoSnap(TempPos.Y, FRefRect.Top);
  if Result then
  begin
    MatchEdge := reTop;
    NewRefRectPos := TempPos;
  end;
end;

function TWindowMatchSnap.HasWorkAreaEdgeMatchBottom(out MatchEdge: TRectEdge; out NewRefRectPos: TPoint): Boolean;
var
  TempPos: TPoint;
begin
  TempPos := GetRefRectDefaultPositionBottom;
  Result := NoSnap(TempPos.Y, FRefRect.Top);
  if Result then
  begin
    MatchEdge := reBottom;
    NewRefRectPos := TempPos;
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
