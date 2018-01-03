unit WinDomina.Layer.Mover;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  Winapi.Windows,
  WinDomina.Layer,
  WinDomina.Registry,
  WinDomina.WindowTools;

type
  TMoverLayer = class(TBaseLayer)
  public
    constructor Create; override;

    procedure EnterLayer; override;
    procedure ExitLayer; override;

    procedure HandleKeyDown(Key: Integer; var Handled: Boolean); override;
    procedure HandleKeyUp(Key: Integer; var Handled: Boolean); override;
  end;

implementation

{ TMoverLayer }

constructor TMoverLayer.Create;
begin
  inherited Create;

  RegisterLayerActivationKeys([vkLeft, vkRight, vkUp, vkDown]);
end;

procedure TMoverLayer.EnterLayer;
begin
  inherited EnterLayer;
  AddLog('TMoverLayer.EnterLayer');
end;

procedure TMoverLayer.ExitLayer;
begin
  AddLog('TMoverLayer.ExitLayer');
  inherited ExitLayer;
end;

procedure TMoverLayer.HandleKeyDown(Key: Integer; var Handled: Boolean);

  procedure MoveSizeWindow(DeltaX, DeltaY: Integer);
  var
    Window: THandle;
    FastMode: Boolean;
    FMStepX, FMStepY: Integer;
    Rect, WorkareaRect, OverSizeRect: TRect;

    procedure AdjustForFastModeStep(var TargetVar: Integer; Step: Integer);
    begin
      TargetVar := (TargetVar div Step) * Step;
    end;

  begin
    if DominaWindows.Count = 0 then
      Exit;

    Window := DominaWindows[0];
    GetWindowRect(Window, Rect);
//    LogMemo.Lines.Add('GetWindowRect: ' + RectToString(Rect));
    WorkareaRect := GetWorkareaRect(Rect);
    GetWindowRectDominaStyle(Window, Rect);
//    LogMemo.Lines.Add('GetWindowRectDominaStyle: ' + RectToString(Rect));
    OverSizeRect := GetWindowNonClientOversize(Window);

    FastMode := not WDMKeyStates.IsShiftKeyPressed;

    if FastMode then
    begin
      FMStepX := (WorkareaRect.Width div 90);
      FMStepY := (WorkareaRect.Height div 90);
      DeltaX := DeltaX * FMStepX;
      DeltaY := DeltaY * FMStepY;
    end
    else
    begin
      FMStepX := 0;
      FMStepY := 0;
    end;

    if WDMKeyStates.IsControlKeyPressed then
    begin
      if FastMode then
      begin
        if DeltaX <> 0 then
          AdjustForFastModeStep(Rect.Right, FMStepX);
        if DeltaY <> 0 then
          AdjustForFastModeStep(Rect.Bottom, FMStepY);
      end;

      Inc(Rect.Right, DeltaX + -OverSizeRect.Right);
      Inc(Rect.Bottom, DeltaY + -OverSizeRect.Bottom);
      SetWindowPos(Window, 0, 0, 0, Rect.Width, Rect.Height, SWP_NOZORDER or SWP_NOMOVE);
    end
    else
    begin
      if FastMode then
      begin
        if DeltaX <> 0 then
          AdjustForFastModeStep(Rect.Left, FMStepX);
        if DeltaY <> 0 then
          AdjustForFastModeStep(Rect.Top, FMStepY);
      end;

      if (Rect.Left <= WorkareaRect.Left) and FastMode and (DeltaX < 0) then
        Rect.Left := WorkareaRect.Left + OverSizeRect.Left
      else
        Inc(Rect.Left, DeltaX + -OverSizeRect.Left);

      if (Rect.Top <= WorkareaRect.Top) and FastMode and (DeltaY < 0) then
        Rect.Top := WorkareaRect.Top + OverSizeRect.Top
      else
        Inc(Rect.Top, DeltaY + -OverSizeRect.Top);

      SetWindowPos(Window, 0, Rect.Left, Rect.Top, 0, 0, SWP_NOZORDER or SWP_NOSIZE);
    end;
  end;

var
  DeltaX, DeltaY: Integer;
begin
  DeltaX := 0;
  DeltaY := 0;

  case Key of
    vkLeft:
      DeltaX := -1;
    VK_RIGHT:
      DeltaX := 1;
    VK_UP:
      DeltaY := -1;
    VK_DOWN:
      DeltaY := 1;
  end;

  if (DeltaX <> 0) or (DeltaY <> 0) then
  begin
    MoveSizeWindow(DeltaX, DeltaY);
    Handled := True;
  end;
end;

procedure TMoverLayer.HandleKeyUp(Key: Integer; var Handled: Boolean);
begin

end;

end.
