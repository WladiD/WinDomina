unit WinDomina.KeyTools;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Defaults,
  System.Generics.Collections,
  System.UITypes,
  System.Diagnostics,
  Vcl.Graphics,

  GR32,
  AnyiQuack;

type
  TKeyState = (ksFlat, ksUp, ksPressed);
  TRenderKey = record
    VirtualKey: Integer;
    State: TKeyState;
    Enabled: Boolean;
    Width: Integer;
    Height: Integer;
  end;

  TKeyRenderer = class
  public
    procedure Render(const Key: TRenderKey; Target: TBitmap32); virtual;
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
    constructor Create;
    destructor Destroy; override;

    procedure Render(const DrawSource: TDrawSource; VirtualKey: Integer; Rect: TRect; State: TKeyState;
      Enabled: Boolean = True); overload;
    procedure Render(Target: TBitmap32; VirtualKey: Integer; Rect: TRect; State: TKeyState;
      Enabled: Boolean = True); overload;
    procedure Render(Target: TCanvas; VirtualKey: Integer; Rect: TRect; State: TKeyState;
      Enabled: Boolean = True); overload;

    property KeyRendererClass: TKeyRendererClass read FKeyRendererClass write SetKeyRendererClass;
  end;

implementation

uses
  WinDomina.Registry;

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
  FCleanupCountThreshold := 128;
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
  State: TKeyState; Enabled: Boolean);
var
  RK: TRenderKey;

  function CreateCachedKey: TCachedKey;
  begin
    Result := TCachedKey.Create;
    Result.FBitmap := TBitmap32.Create(RK.Width, RK.Height);
    FKeyRenderer.Render(RK, Result.FBitmap);
  end;

var
  CachedKey: TCachedKey;
  Stopper: TStopwatch;
begin
  RK := Default(TRenderKey);
  RK.VirtualKey := VirtualKey;
  RK.State := State;
  RK.Enabled := Enabled;
  RK.Width := Rect.Width;
  RK.Height := Rect.Height;

  if not FCachedKeys.TryGetValue(RK, CachedKey) then
  begin
    Stopper := TStopwatch.StartNew;
    CachedKey := CreateCachedKey;
    Stopper.Stop;
    FCachedKeys.Add(RK, CachedKey);
    Logging.AddLog(Format('Duration for render: %d msec. FCachedKeys.Count = %d',
      [Stopper.ElapsedMilliseconds, FCachedKeys.Count]));
  end;

  CachedKey.FLastUsed := GetTickCount;

  DrawSource(CachedKey.FBitmap, Rect);

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
  State: TKeyState; Enabled: Boolean);
begin
  Render(
    procedure(Source: TBitmap32; Rect: TRect)
    begin
      Target.Draw(Rect.Left, Rect.Top, Source);
    end,
    VirtualKey, Rect, State, Enabled);
end;

procedure TKeyRenderManager.Render(Target: TCanvas; VirtualKey: Integer; Rect: TRect;
  State: TKeyState; Enabled: Boolean);
begin
  Render(
    procedure(Source: TBitmap32; Rect: TRect)
    begin
      Source.DrawTo(Target.Handle);
    end,
    VirtualKey, Rect, State, Enabled);
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

procedure TKeyRenderer.Render(const Key: TRenderKey; Target: TBitmap32);

  function CalcFontSize(Bitmap: TBitmap32; Text: string): Integer;
  var
    PrevSize: Integer;
    Extent: TSize;
  begin
    PrevSize := 0;
    Result := 12;
    while True do
    begin
      Bitmap.Font.Size := -Result;
      Extent := Bitmap.TextExtent(Text);
      if (Extent.cx < Bitmap.Width) and (Extent.cy < Bitmap.Height) then
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

var
  KeyText: string;
  FontSize: Integer;
  BGRect: TRect;
  TextSize: TSize;
begin
  Target.Font.Name := 'Arial';
  Target.Font.Style := [];
  KeyText := GetKeyText;
  BGRect := Rect(0, 0, Target.Width, Target.Height);

  Target.FrameRectS(BGRect, clBlack32);
  BGRect.Inflate(-1, -1);
  Target.FrameRectS(BGRect, clBlack32);
  BGRect.Inflate(-1, -1);
  Target.FillRectTS(BGRect, SetAlpha(clWhite32, 180));

  if KeyText <> '' then
  begin
    FontSize := CalcFontSize(Target, KeyText);
    Target.Font.Size := FontSize;

    TextSize := Target.TextExtent(KeyText);
    Target.RenderText(
      BGRect.Left + ((BGRect.Width - TextSize.cx) div 2),
      BGRect.Top + ((BGRect.Height - TextSize.cy) div 2),
      KeyText, 2, clBlack32);
  end;
end;

end.
