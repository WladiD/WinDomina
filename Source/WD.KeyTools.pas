unit WD.KeyTools;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Defaults,
  System.Generics.Collections,
  System.UITypes,
  System.Diagnostics,
  System.Types,
  System.Math,
  Vcl.Graphics,

  GR32,
  GR32_Polygons,
  GR32_Blend,

  AnyiQuack,
  Localization,
  WD.Types,
  WD.GR32Tools,
  WDDT.DelayedMethod;

type
  TKeyRenderer = class;
  TKeyDecoratorProc = reference to procedure(Renderer: TKeyRenderer; Target: TBitmap32;
    KeyRect: TRect);

  TKeyState = (ksFlat, ksUp, ksPressed);
  TRenderKey = record
    VirtualKey: Integer;
    State: TKeyState;
    Enabled: Boolean;
    Width: Integer;
    Height: Integer;
    Decorator: TKeyDecoratorProc;
  end;

  TKeyRenderer = class
  public
    procedure Render(const Key: TRenderKey; Target: TBitmap32; KeyRect: TRect); virtual;
  end;

  TKeyRendererClass = class of TKeyRenderer;
  TDrawSource = reference to procedure(Source: TBitmap32; Rect: TRect);

  TKeyRenderManager = class(TComponent)
  private
    type
    TCachedKey = class
    private
      FBitmap: TBitmap32;
      FLastUsed: Cardinal;
    public
      destructor Destroy; override;
    end;

    TCachedKeys = TObjectDictionary<TRenderKey, TCachedKey>;
    TRenderKeys = TList<TRenderKey>;

    var
    FCachedKeys: TCachedKeys;
    FKeyRenderer: TKeyRenderer;
    FKeyRendererClass: TKeyRendererClass;
    // Wird der Wert überschritten, wird der Bereinigungsvorgang ausgelöst
    FCleanupCountThreshold: Integer;
    // Anteil an zu löschenden Einträgen als Faktor (> 0 <= 1),
    // wenn es zu einem Bereinigungsvorgang kommt
    FCleanupFactor: Single;

    procedure Cleanup;
    procedure SetKeyRendererClass(Value: TKeyRendererClass);

  public
    class constructor Create;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;

    procedure Render(const DrawSource: TDrawSource; VirtualKey: Integer; Rect: TRect; State: TKeyState;
      Enabled: Boolean = True; const Decorator: TKeyDecoratorProc = nil); overload;
    procedure Render(Target: TBitmap32; VirtualKey: Integer; Rect: TRect; State: TKeyState;
      Enabled: Boolean = True; const Decorator: TKeyDecoratorProc = nil); overload;

    property KeyRendererClass: TKeyRendererClass read FKeyRendererClass write SetKeyRendererClass;
  end;

implementation

uses
  WD.Registry;

{ TKeyRenderManager.TCachedKey }

destructor TKeyRenderManager.TCachedKey.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

{ TKeyRenderManager }

class constructor TKeyRenderManager.Create;
begin

end;

constructor TKeyRenderManager.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FCachedKeys := TCachedKeys.Create([doOwnsValues]);
  KeyRendererClass := TKeyRenderer;
  FCleanupCountThreshold := 512;
  FCleanupFactor := 0.5; // Standardmäßig soll die Hälfte der Einträge entfernt werden
end;

destructor TKeyRenderManager.Destroy;
begin
  FCachedKeys.Free;
  FKeyRenderer.Free;

  inherited Destroy;
end;

procedure TKeyRenderManager.Cleanup;

  function GetRenderKey(ForCachedKey: TCachedKey): TRenderKey;
  var
    Pair: TPair<TRenderKey, TCachedKey>;
  begin
    for Pair in FCachedKeys do
      if ForCachedKey = Pair.Value then
        Exit(Pair.Key);
    Result := Default(TRenderKey);
  end;

var
  OnlyCachedKeys: TList<TCachedKey>;
  cc: Integer;
begin
  OnlyCachedKeys := TList<TCachedKey>.Create;
  try
    OnlyCachedKeys.AddRange(FCachedKeys.Values);
    // Absteigend sortieren
    OnlyCachedKeys.Sort(TDelegatedComparer<TCachedKey>.Create(
      function(const Left, Right: TCachedKey): Integer
      begin
        Result := Right.FLastUsed - Left.FLastUsed;
      end));

    for cc := Round(OnlyCachedKeys.Count * FCleanupFactor) to OnlyCachedKeys.Count - 1 do
      FCachedKeys.Remove(GetRenderKey(OnlyCachedKeys[cc]));
  finally
    OnlyCachedKeys.Free;
  end;
end;

procedure TKeyRenderManager.Render(const DrawSource: TDrawSource; VirtualKey: Integer; Rect: TRect;
  State: TKeyState; Enabled: Boolean; const Decorator: TKeyDecoratorProc);
var
  RK: TRenderKey;

  function CreateCachedKey: TCachedKey;
  begin
    Result := TCachedKey.Create;
    Result.FBitmap := TBitmap32.Create(RK.Width, RK.Height);
    FKeyRenderer.Render(RK, Result.FBitmap, System.Types.Rect(0, 0, RK.Width, RK.Height));
  end;

var
  CachedKey: TCachedKey;
begin
  RK := Default(TRenderKey);
  RK.VirtualKey := VirtualKey;
  RK.State := State;
  RK.Enabled := Enabled;
  RK.Width := Rect.Width;
  RK.Height := Rect.Height;
  RK.Decorator := Decorator;

  if not FCachedKeys.TryGetValue(RK, CachedKey) then
  begin
    CachedKey := CreateCachedKey;
    FCachedKeys.Add(RK, CachedKey);
  end;

  DrawSource(CachedKey.FBitmap, Rect);
  CachedKey.FLastUsed := GetTickCount;

  if FCachedKeys.Count > FCleanupCountThreshold then
    TDelayedMethod.Execute(Cleanup, 1000);
end;

procedure TKeyRenderManager.Render(Target: TBitmap32; VirtualKey: Integer; Rect: TRect;
  State: TKeyState; Enabled: Boolean; const Decorator: TKeyDecoratorProc);
var
  RK: TRenderKey;
begin
  RK := Default(TRenderKey);
  RK.VirtualKey := VirtualKey;
  RK.State := State;
  RK.Enabled := Enabled;
  RK.Width := Rect.Width;
  RK.Height := Rect.Height;
  RK.Decorator := Decorator;

  Render(
    procedure(Source: TBitmap32; Rect: TRect)
    begin
      MergedDraw(Source, Target, Rect.Left, Rect.Top);
    end,
    VirtualKey, Rect, State, Enabled, Decorator);
end;

procedure TKeyRenderManager.SetKeyRendererClass(Value: TKeyRendererClass);
begin
  if Value <> FKeyRendererClass then
  begin
    FCachedKeys.Clear;
    FKeyRendererClass := Value;
    FKeyRenderer.Free;
    FKeyRenderer := FKeyRendererClass.Create;
  end;
end;

{ TKeyRenderer }

procedure TKeyRenderer.Render(const Key: TRenderKey; Target: TBitmap32; KeyRect: TRect);

  function CalcFontHeight(Text: string): Integer;
  var
    PrevHeight: Integer;
    Extent: TSize;
    PadX, PadY, AvailWidth, AvailHeight: Integer;
  begin
    PrevHeight := 0;
    Result := 6;

    if Length(Text) > 1 then
    begin
      PadX := Round(KeyRect.Width * 0.25);
      PadY := Round(KeyRect.Height * 0.15);
    end
    else
    begin
      PadX := Round(KeyRect.Width * 0.05);
      PadY := Round(KeyRect.Height * 0.05);
    end;

    PadX := Max(4, PadX);
    PadY := Max(4, PadY);
    AvailWidth := KeyRect.Width - PadX;
    AvailHeight := KeyRect.Height - PadY;

    while True do
    begin
      Target.Font.Height := Result;
      Extent := Target.TextExtent(Text);

      if (Extent.cx >= AvailWidth) or (Extent.cy >= AvailHeight) then
        Exit(PrevHeight);

      PrevHeight := Result;
      Inc(Result, 4);
    end;
  end;

  function GetKeyText: string;
  begin
    case Key.VirtualKey of
      vkNumpad0..vkNumpad9:
        Result := IntToStr(Key.VirtualKey - vkNumpad0);
      vk0..vk9:
        Result := IntToStr(Key.VirtualKey - vk0);
      vkA..vkZ:
        Result := string(AnsiChar(Key.VirtualKey));
      vkEscape:
        Result := Lang.Consts['KeyEscapeShort'];
    else
      Result := '';
    end;
  end;

  procedure DrawArrow(const P1, P2, P3: TFloatPoint);
  var
    Points: TArrayOfFloatPoint;
  begin
    SetLength(Points, 3);
    Points[0] := P1;
    Points[1] := P2;
    Points[2] := P3;

    PolygonFS(Target, Points, clBlack32);
  end;

var
  ArrowIndent: Integer;

  procedure DrawArrowLeft;
  begin
    DrawArrow(
      FloatPoint(KeyRect.Left + ArrowIndent, KeyRect.Top + (KeyRect.Height / 2)),
      FloatPoint(KeyRect.Right - ArrowIndent, KeyRect.Top + ArrowIndent),
      FloatPoint(KeyRect.Right - ArrowIndent, KeyRect.Bottom - ArrowIndent));
  end;

  procedure DrawArrowRight;
  begin
    DrawArrow(
      FloatPoint(KeyRect.Left + ArrowIndent, KeyRect.Top + ArrowIndent),
      FloatPoint(KeyRect.Right - ArrowIndent, KeyRect.Top + (KeyRect.Height / 2)),
      FloatPoint(KeyRect.Left + ArrowIndent, KeyRect.Bottom - ArrowIndent));
  end;

  procedure DrawArrowUp;
  begin
    DrawArrow(
      FloatPoint(KeyRect.Left + (KeyRect.Width / 2), KeyRect.Top + ArrowIndent),
      FloatPoint(KeyRect.Right - ArrowIndent, KeyRect.Bottom - ArrowIndent),
      FloatPoint(KeyRect.Left + ArrowIndent, KeyRect.Bottom - ArrowIndent));
  end;

  procedure DrawArrowDown;
  begin
    DrawArrow(
      FloatPoint(KeyRect.Left + ArrowIndent, KeyRect.Top + ArrowIndent),
      FloatPoint(KeyRect.Right - ArrowIndent, KeyRect.Top + ArrowIndent),
      FloatPoint(KeyRect.Left + (KeyRect.Width / 2), KeyRect.Bottom - ArrowIndent));
  end;

var
  KeyText: string;
  FontHeight: Integer;
  TextSize: TSize;
begin
  Target.Font.Name := 'Arial';
  Target.Font.Style := [];
  KeyText := GetKeyText;

  Target.FrameRectS(KeyRect, clBlack32);
  KeyRect.Inflate(-1, -1);
  Target.FrameRectS(KeyRect, clBlack32);
  KeyRect.Inflate(-1, -1);
  Target.FillRectTS(KeyRect, SetAlpha(clWhite32, 180));

  if KeyText <> '' then
  begin
    FontHeight := CalcFontHeight(KeyText);
    Target.Font.Height := FontHeight;

    TextSize := Target.TextExtent(KeyText);
    Target.RenderTextWD(
      KeyRect.Left + ((KeyRect.Width - TextSize.cx) div 2),
      KeyRect.Top + ((KeyRect.Height - TextSize.cy) div 2),
      KeyText, clBlack32);
  end
  else if Key.VirtualKey in [vkLeft, vkRight, vkUp, vkDown] then
  begin
    ArrowIndent := Round(Key.Width * 0.25);

    case Key.VirtualKey of
      vkLeft:
        DrawArrowLeft;
      vkRight:
        DrawArrowRight;
      vkUp:
        DrawArrowUp;
      vkDown:
        DrawArrowDown;
    end;
  end;

  if Assigned(Key.Decorator) then
    Key.Decorator(Self, Target, KeyRect);
end;

end.
