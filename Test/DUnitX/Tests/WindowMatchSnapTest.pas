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
    procedure MatchSimple(Direction: TDirection; const RefRect: TRect; const ExpectedPos: TPoint);

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
    // Hier greift der Snap-Mechanismus (Toleranz von 5px)
    [TestCase('RectA_Left_2', '204, 150, 300, 300, 100, 150')]
    // Hier greift der Snap-Mechanismus NICHT
    [TestCase('RectA_Right_2', '205, 150, 300, 300, 200, 150')]
    [TestCase('RectB_Left_1', '400, 600, 500, 700, 300, 600')]
    [TestCase('RectB_Left_2', '350, 300, 400, 350, 300, 300')]
    [TestCase('RectB_Right_2', '600, 300, 700, 400, 500, 300')]
    // Keine Übereinstimmung, da zu weit links
    [TestCase('NoMatch_1', '50, 50, 100, 100, -1, -1')]
    [TestCase('NoMatch_2', '0, 0, 100, 100, -1, -1')]
    procedure MatchLeftSimple(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);

    [Test]
    // Die Testfälle laufen gegen die folgenden Fenster:
    // - RectA(100, 100, 200, 200)
    // - RectB(300, 300, 500, 500)
    [TestCase('RectA_Left_1', '0, 75, 50, 125, 50, 75')]
    [TestCase('RectA_Right_1', '100, 75, 150, 125, 150, 75')]
    [TestCase('RectB_Left_1', '200, 75, 250, 125, 250, 75')]
    [TestCase('RectB_Right_1', '350, 75, 450, 125, 400, 75')]
    procedure MatchLeftRight(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft, ExpectedTop: Integer);
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

procedure TWindowMatchSnapTest.MatchSimple(Direction: TDirection; const RefRect: TRect;
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
      Assert.IsTrue(MatchEdge in [reLeft, reRight], 'Matching edge should be reLeft or reRight');
      Assert.AreEqual(ExpectedPos.X, NewPos.X);
      Assert.AreEqual(ExpectedPos.Y, NewPos.Y);
    end;
  finally
    WMS.Free;
  end;
end;

procedure TWindowMatchSnapTest.MatchLeftSimple(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft,
  ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSimple(dirLeft, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

procedure TWindowMatchSnapTest.MatchLeftRight(RefLeft, RefTop, RefRight, RefBottom, ExpectedLeft,
  ExpectedTop: Integer);
begin
  AddWindow(Rect(100, 100, 200, 200));
  AddWindow(Rect(300, 300, 500, 500));
  MatchSimple(dirRight, Rect(RefLeft, RefTop, RefRight, RefBottom),
    Point(ExpectedLeft, ExpectedTop));
end;

initialization
  TDUnitX.RegisterTestFixture(TWindowMatchSnapTest);

end.
