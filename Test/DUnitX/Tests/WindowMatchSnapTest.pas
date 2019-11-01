unit WindowMatchSnapTest;

interface

uses
  DUnitX.TestFramework,
  System.Types,
  System.SysUtils,

  WindowEnumerator,
  WinDomina.WindowMatchSnap;

type
  [TestFixture]
  TWindowMatchSnapTest = class
  private
    FWindowList: TWindowList;

  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure CreateAndDestroy;
    [Test]
    [TestCase('A', '')]
    procedure MatchLeftSimple(RefLeft, RefTop, RefRight, RefBottom: Integer);


    // Test with TestCase Attribute to supply parameters.
//    [Test]
//    [TestCase('TestA','1,2')]
//    [TestCase('TestB','3,4')]
//    procedure Test2(const AValue1 : Integer;const AValue2 : Integer);
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

procedure TWindowMatchSnapTest.CreateAndDestroy;
var
  WMS: TWindowMatchSnap;
  List: TWindowList;
begin
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

procedure TWindowMatchSnapTest.MatchLeftSimple(RefLeft, RefTop, RefRight, RefBottom: Integer);
var
  List: TWindowList;
begin

end;

//procedure TWindowMatchSnapTest.Test2(const AValue1 : Integer;const AValue2 : Integer);
//begin
//
//end;

initialization
  TDUnitX.RegisterTestFixture(TWindowMatchSnapTest);

end.
