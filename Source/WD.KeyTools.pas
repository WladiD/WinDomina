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
  Vcl.Graphics,

  GR32,
  GR32_Polygons,
  AnyiQuack,
  WD.Types;

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

  TKeyRenderManager = class
  private
    class var
    CleanupDelayID: Integer;

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
    FKnownFastRenderKeys: TRenderKeys;
    FKeyRenderer: TKeyRenderer;
    FKeyRendererClass: TKeyRendererClass;
    // Wird der Wert überschritten, wird der Bereinigungsvorgang ausgelöst
    FCleanupCountThreshold: Integer;
    // Anteil an zu löschenden Einträgen als Faktor (> 0 <= 1),
    // wenn es zu einem Bereinigungsvorgang kommt
    FCleanupFactor: Single;

    procedure Cleanup;
    procedure SetKeyRendererClass(Value: TKeyRendererClass);

    procedure AddKnownFastRenderKey(const RenderKey: TRenderKey);
    function IsKnownFastRenderKey(const RenderKey: TRenderKey): Boolean;

  public
    class constructor Create;
    constructor Create;
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
  CleanupDelayID := TAQ.GetUniqueID;
end;

constructor TKeyRenderManager.Create;
begin
  FCachedKeys := TCachedKeys.Create([doOwnsValues]);
  KeyRendererClass := TKeyRenderer;
  FKnownFastRenderKeys := TRenderKeys.Create(
    TDelegatedComparer<TRenderKey>.Create(
      function(const Left, Right: TRenderKey): Integer
      begin
        // Für das Wissen "Das Rendering ist bei dem Key schnell" braucht man nur wenige Kriterien.
        // Die Größe des Keys ist z.B. nicht relevant.
        if (Left.VirtualKey = Right.VirtualKey) and
          (Left.State = Right.State) and (Left.Enabled = Right.Enabled) and
          (Left.Decorator = Right.Decorator) then
          Result := 0
        else
          Result := 1;
      end));
  FCleanupCountThreshold := 128;
  FCleanupFactor := 0.5; // Standardmäßig soll die Hälfte der Einträge entfernt werden
end;

destructor TKeyRenderManager.Destroy;
begin
  FCachedKeys.Free;
  FKeyRenderer.Free;
  FKnownFastRenderKeys.Free;

  inherited Destroy;
end;

procedure TKeyRenderManager.AddKnownFastRenderKey(const RenderKey: TRenderKey);
begin
  FKnownFastRenderKeys.Add(RenderKey);
end;

function TKeyRenderManager.IsKnownFastRenderKey(const RenderKey: TRenderKey): Boolean;
begin
  Result := FKnownFastRenderKeys.IndexOf(RenderKey) >= 0;
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
  CacheKey: Boolean;
  CachedKey: TCachedKey;
  Stopper: TStopwatch;
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
    Stopper := TStopwatch.StartNew;
    CachedKey := CreateCachedKey;
    Stopper.Stop;

    // Gecacht soll nur, wenn das Rendering zu lange dauert
    CacheKey := Stopper.ElapsedMilliseconds > 0;
    if CacheKey then
      FCachedKeys.Add(RK, CachedKey)
    else if not IsKnownFastRenderKey(RK) then
      AddKnownFastRenderKey(RK);

//    Logging.AddLog(Format('Duration for render: %d msec. FCachedKeys.Count = %d',
//      [Stopper.ElapsedMilliseconds, FCachedKeys.Count]));
  end
  else
    CacheKey := True;

  DrawSource(CachedKey.FBitmap, Rect);

  if CacheKey then
    CachedKey.FLastUsed := GetTickCount
  // Wenn das Rendering schnell war und es nicht gecacht wird, dann freigeben.
  else
    CachedKey.Free;

  if FCachedKeys.Count > FCleanupCountThreshold then
    Take(Self)
      .CancelDelays(CleanupDelayID)
      .EachDelay(1000,
        function(AQ: TAQ; O: TObject): Boolean
        begin
          Cleanup;
          Result := False;
        end, CleanupDelayID);
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

  // Die schnellste Methode, wenn zuvor bereits bekannt geworden ist,
  // dass das Rendering für diesen Key ganz schnell ist.
  if IsKnownFastRenderKey(RK) then
  begin
    FKeyRenderer.Render(RK, Target, Rect);
    Exit;
  end;

  Render(
    procedure(Source: TBitmap32; Rect: TRect)
    begin
      Target.Draw(Rect.Left, Rect.Top, Source);
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

  function CalcFontSize(Text: string): Integer;
  var
    PrevSize: Integer;
    Extent: TSize;
  begin
    PrevSize := 0;
    Result := 12;
    while True do
    begin
      Target.Font.Size := -Result;
      Extent := Target.TextExtent(Text);
      if (Extent.cx < KeyRect.Width) and (Extent.cy < KeyRect.Height) then
        Inc(Result)
      else
        Exit(PrevSize);
      PrevSize := Result
    end;
  end;

  function GetKeyText: string;
  var
    VK, NumKey: Integer;
  begin
    Result := '';
    VK := Key.VirtualKey;

    if VK in [vkNumpad0..vkNumpad9] then
      NumKey := (VK - vkNumpad0)
    else if VK in [vk0..vk9] then
      NumKey := (VK - vk0)
    else
      NumKey := -1;

    if NumKey >= 0 then
      Result := IntToStr(NumKey);
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
  FontSize: Integer;
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
    FontSize := CalcFontSize(KeyText);
    Target.Font.Size := FontSize;

    TextSize := Target.TextExtent(KeyText);
    Target.RenderText(
      KeyRect.Left + ((KeyRect.Width - TextSize.cx) div 2),
      KeyRect.Top + ((KeyRect.Height - TextSize.cy) div 2),
      KeyText, 2, clBlack32);
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
