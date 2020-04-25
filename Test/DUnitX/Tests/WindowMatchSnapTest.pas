unit WindowMatchSnapTest;

interface

uses
  Winapi.Windows,
  DUnitX.TestFramework,
  System.Types,
  System.SysUtils,

  WindowEnumerator,
  WinDomina.Types,
  WinDomina.WindowMatchSnap;

type
  [TestFixture]
  TWindowMatchSnapTest = class
  private
    FWindowList: TWindowList;

    procedure AddWindow(const Rect: TRect; Handle: HWND = 0; const Text: string = '';
      const ClassName: string = '');
    procedure MatchSnapWindow(Direction: TDirection; const RefRect: TRect; const ExpectedPos: TPoint);
    procedure MatchWorkAreaEdge(Direction: TDirection; const RefRect: TRect; const ExpectedPos: TPoint);

    property WindowList: TWindowList read FWindowList;

  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure CreateAndDestroy;

    [Test]
    // Die Testfälle laufen gegen die folgenden Fenster:
    // - RectA(100, 100, 200, 200)
    // - RectB(300, 300, 500, 500)
    [TestCase('RectA_Left_1', '150, 150, 300, 300, 100, 150')]
    [TestCase('RectA_Right_1', '250, 150, 300, 300, 200, 150')]
    [TestCase('RectA_Left_2', '204, 150, 300, 300, 100, 150')]
    [TestCase('RectA_Right_2', '205, 150, 300, 300, 200, 150')]
    [TestCase('RectB_Left_1', '400, 600, 500, 700, 300, 600')]
    [TestCase('RectB_Left_2', '350, 300, 400, 350, 300, 300')]
    [TestCase('RectB_Right_2', '600, 300, 700, 400, 500, 300')]
    [TestCase('NoMatch_1', '50, 50, 100, 100, -1, -1')]
    [TestCase('NoMatch_2', '0, 0, 100, 100, -1, -1')]
    procedure MatchSnapWindowLeft(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen die folgenden Fenster:
    // - RectA(100, 100, 200, 200)
    // - RectB(300, 300, 500, 500)
    [TestCase('RectA_Left_1', '0, 75, 50, 125, 50, 75')]
    [TestCase('RectA_Right_1', '100, 75, 150, 125, 150, 75')]
    [TestCase('RectB_Left_1', '200, 75, 250, 125, 250, 75')]
    [TestCase('RectB_Right_1', '350, 75, 450, 125, 400, 75')]
    [TestCase('RectB_Left_2', '150, 75, 198, 125, 252, 75')]
    [TestCase('RectA_Right_2', '145, 75, 195, 125, 150, 75')]
    [TestCase('NoMatch_1', '400, 600, 498, 700, -1, -1')]
    [TestCase('NoMatch_2', '400, 600, 500, 700, -1, -1')]
    [TestCase('NoMatch_3', '600, 0, 700, 700, -1, -1')]
    procedure MatchSnapWindowRight(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen die folgenden Fenster:
    // - RectA(100, 100, 200, 200)
    // - RectB(300, 300, 500, 500)
    [TestCase('RectA_Top_1', '0, 150, 50, 200, 0, 100')]
    [TestCase('RectA_Bottom_1', '350, 250, 450, 300, 350, 200')]
    [TestCase('RectB_Top_1', '350, 350, 450, 400, 350, 300')]
    [TestCase('RectB_Bottom_1', '350, 600, 450, 700, 350, 500')]
    [TestCase('RectA_Bottom_2', '350, 303, 450, 700, 350, 200')]
    [TestCase('RectB_Top_2', '350, 305, 450, 700, 350, 300')]
    [TestCase('NoMatch_1', '350, 50, 450, 700, -1, -1')]
    [TestCase('NoMatch_2', '350, 50, 450, 100, -1, -1')]
    [TestCase('NoMatch_3', '350, 100, 450, 200, -1, -1')]
    procedure MatchSnapWindowTop(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen die folgenden Fenster:
    // - RectA(100, 100, 200, 200)
    // - RectB(300, 300, 500, 500)
    [TestCase('RectA_Top_1', '0, 50, 50, 80, 0, 70')]
    [TestCase('RectA_Bottom_1', '100, 120, 150, 170, 100, 150')]
    [TestCase('RectB_Top_1', '120, 150, 150, 250, 120, 200')]
    [TestCase('RectB_Bottom_1', '100, 350, 150, 400, 100, 450')]
    [TestCase('RectB_Top_2', '100, 149, 150, 199, 100, 250')]
    [TestCase('RectA_Bottom_2', '100, 145, 150, 195, 100, 150')]
    [TestCase('NoMatch_1', '300, 300, 500, 500, -1, -1')]
    [TestCase('NoMatch_2', '100, 500, 200, 600, -1, -1')]
    [TestCase('NoMatch_3', '100, 550, 200, 650, -1, -1')]
    procedure MatchSnapWindowBottom(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen eine Workarea von Rect(0, 0, 1000, 1000)
    [TestCase('Left', '100, 100, 200, 200, 0, 100')]
    [TestCase('NoMatch', '0, 100, 200, 200, -1, -1')]
    procedure MatchWorkAreaEdgeLeft(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen eine Workarea von Rect(0, 0, 1000, 1000)
    [TestCase('Right', '100, 100, 200, 200, 900, 100')]
    [TestCase('NoMatch', '900, 100, 1000, 200, -1, -1')]
    procedure MatchWorkAreaEdgeRight(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen eine Workarea von Rect(0, 0, 1000, 1000)
    [TestCase('Top', '100, 100, 200, 200, 100, 0')]
    [TestCase('NoMatch', '100, 0, 200, 200, -1, -1')]
    procedure MatchWorkAreaEdgeTop(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen eine Workarea von Rect(0, 0, 1000, 1000)
    [TestCase('Bottom', '100, 100, 200, 200, 100, 900')]
    [TestCase('NoMatch', '100, 900, 200, 1000, -1, -1')]
    procedure MatchWorkAreaEdgeBottom(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);
  end;

implementation

procedure TWindowMatchSnapTest.Setup;
begin
  FWindowList := TWindowList.Create;
end;

procedure TWindowMatchSnapTest.TearDown;
begin
  FWindowList.Free;
end;

procedure TWindowMatchSnapTest.AddWindow(const Rect: TRect; Handle: HWND;
  const Text, ClassName: string);
var
  Window: TWindow;
begin
  Window := TWindow.Create;
  Window.Rect := Rect;
  Window.Handle := Handle;
  Window.Text := Text;
  Window.ClassName := ClassName;
  WindowList.Add(Window);
end;

procedure TWindowMatchSnapTest.CreateAndDestroy;
var
  WMS: TWindowMatchSnap;
  List: TWindowList;
begin
  Assert.IsNotNull(FWindowList);

  WMS := nil;
  List := TWindowList.Create;
  try
    List.Add(TWindow.Create);
    // Hier will ich sicherstellen, dass die an TWindowMatchSnap übergebene TWindowList
    // dort nicht freigegeben wird.
    WMS := TWindowMatchSnap.Create(Rect(10, 10, 20, 20), Rect(0, 0, 600, 600), List);
    FreeAndNil(WMS);
    Assert.IsNotNull(List[0]);

    List.Add(TWindow.Create);
    Assert.AreEqual(2, List.Count);
  finally
    List.Free;
    WMS.Free;
  end;
end;

procedure TWindowMatchSnapTest.MatchSnapWindow(Direction: TDirection; const RefRect: TRect;
  const ExpectedPos: TPoint);
var
  WMS: TWindowMatchSnap;
  MatchWindow: TWindow;
  MatchEdge: TRectEdge;
  NewPos: TPoint;
  MatchExpected, MatchActual: Boolean;
begin
  WMS := TWindowMatchSnap.Create(RefRect, Rect(0, 0, 1000, 1000), WindowList);
  try
    MatchExpected := (ExpectedPos.X >= 0) and (ExpectedPos.Y >= 0);

    case Direction of
      dirUp:
        MatchActual := WMS.HasMatchSnapWindowTop(MatchWindow, MatchEdge, NewPos);
      dirRight:
        MatchActual := WMS.HasMatchSnapWindowRight(MatchWindow, MatchEdge, NewPos);
      dirDown:
        MatchActual := WMS.HasMatchSnapWindowBottom(MatchWindow, MatchEdge, NewPos);
      dirLeft:
        MatchActual := WMS.HasMatchSnapWindowLeft(MatchWindow, MatchEdge, NewPos);
    else
      Exit;
    end;

    Assert.IsTrue(MatchExpected = MatchActual, 'No expected match');
    if MatchExpected then
    begin
      if Direction in [dirLeft, dirRight] then
        Assert.IsTrue(MatchEdge in [reLeft, reRight], 'Matching edge should be reLeft or reRight')
      else
        Assert.IsTrue(MatchEdge in [reTop, reBottom], 'Matching edge should be reTop or reBottom');
      Assert.AreEqual(ExpectedPos.X, NewPos.X);
      Assert.AreEqual(ExpectedPos.Y, NewPos.Y);
    end;
  finally
    WMS.Free;
  end;
end;

procedure TWindowMatchSnapTest.MatchWorkAreaEdge(Direction: TDirection; const RefRect: TRect;
  const ExpectedPos: TPoint);
var
  WMS: TWindowMatchSnap;
  MatchEdge: TRectEdge;
  NewPos: TPoint;
  MatchExpected, MatchActual: Boolean;
begin
  WMS := TWindowMatchSnap.Create(RefRect, Rect(0, 0, 1000, 1000), WindowList);
  try
    MatchExpected := (ExpectedPos.X >= 0) and (ExpectedPos.Y >= 0);

    case Direction of
      dirUp:
        MatchActual := WMS.HasWorkAreaEdgeMatchTop(MatchEdge, NewPos);
      dirRight:
        MatchActual := WMS.HasWorkAreaEdgeMatchRight(MatchEdge, NewPos);
      dirDown:
        MatchActual := WMS.HasWorkAreaEdgeMatchBottom(MatchEdge, NewPos);
      dirLeft:
        MatchActual := WMS.HasWorkAreaEdgeMatchLeft(MatchEdge, NewPos);
    else
      Exit;
    end;

    Assert.IsTrue(MatchExpected = MatchActual, 'No expected match');
    if MatchExpected then
    begin
      if Direction in [dirLeft, dirRight] then
        Assert.IsTrue(MatchEdge in [reLeft, reRight], 'Matching edge should be reLeft or reRight')
      else
        Assert.IsTrue(MatchEdge in [reTop, reBottom], 'Matching edge should be reTop or reBottom');
      Assert.AreEqual(ExpectedPos.X, NewPos.X);
      Assert.AreEqual(ExpectedPos.Y, NewPos.Y);
    end;
  finally
    WMS.Free;
  end;
end;

procedure TWindowMatchSnapTest.MatchSnapWindowLeft(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft,
  ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSnapWindow(dirLeft, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchSnapWindowRight(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft,
  ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSnapWindow(dirRight, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchSnapWindowTop(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft,
  ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSnapWindow(dirUp, Rect(RefLeft, RefTop, RefRight, RefBottom), Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchSnapWindowBottom(RefLeft, RefTop, RefRight, RefBottom,
  ExpectedLeft, ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSnapWindow(dirDown, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchWorkAreaEdgeLeft(RefLeft, RefTop, RefRight, RefBottom,
  ExpectedLeft, ExpectedTop: Integer);
begin
  MatchWorkAreaEdge(dirLeft, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchWorkAreaEdgeRight(RefLeft, RefTop, RefRight, RefBottom,
  ExpectedLeft, ExpectedTop: Integer);
begin
  MatchWorkAreaEdge(dirRight, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchWorkAreaEdgeTop(RefLeft, RefTop, RefRight, RefBottom,
  ExpectedLeft, ExpectedTop: Integer);
begin
  MatchWorkAreaEdge(dirUp, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchWorkAreaEdgeBottom(RefLeft, RefTop, RefRight, RefBottom,
  ExpectedLeft, ExpectedTop: Integer);
begin
  MatchWorkAreaEdge(dirDown, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

initialization
  TDUnitX.RegisterTestFixture(TWindowMatchSnapTest);

end.
