// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.Form.Settings;

interface

uses

  Winapi.Messages,
  Winapi.Windows,

  System.Classes,
  System.IniFiles,
  System.SysUtils,
  System.Variants,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,

  Localization,
  WD.LangIndex,
  WD.Types.Actions;

type

  TSettingsForm = class(TForm, ITranslate)
    ButtonCancel: TButton;
    ButtonOK: TButton;
    ComboBoxCapsLock: TComboBox;
    ComboBoxLeftWin: TComboBox;
    ComboBoxRightCtrl: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
  protected // ITranslate
    function  IsReadyForTranslate: Boolean;
    procedure OnReadyForTranslate(NotifyEvent: TNotifyEvent);
    procedure Translate;
  public
    procedure AfterConstruction; override;
  end;

implementation

{$R *.dfm}

procedure TSettingsForm.AfterConstruction;
begin
  inherited;
  Lang.Translate(Self);
end;

{ TSettingsForm }

function TSettingsForm.IsReadyForTranslate: Boolean;
begin
  Result := True;
end;

procedure TSettingsForm.OnReadyForTranslate(NotifyEvent: TNotifyEvent);
begin
  // Not needed
end;

procedure TSettingsForm.Translate;
var
  Idx: Integer;
begin
  Caption := Lang[LS_17];
  Label1.Caption := Lang[LS_18];
  Label2.Caption := Lang[LS_19];
  Label3.Caption := Lang[LS_20];
  ButtonOK.Caption := Lang.Consts['SMsgDlgOK'];
  ButtonCancel.Caption := Lang.Consts['Cancel'];

  // ComboBoxCapsLock
  Idx := ComboBoxCapsLock.ItemIndex;
  ComboBoxCapsLock.Items.BeginUpdate;
  try
    ComboBoxCapsLock.Items.Clear;
    ComboBoxCapsLock.Items.Add(Lang[LS_21]);
    ComboBoxCapsLock.Items.Add(Lang[LS_22]);
    ComboBoxCapsLock.Items.Add(Lang[LS_23]);
    if (Idx >= 0) and (Idx < ComboBoxCapsLock.Items.Count) then
      ComboBoxCapsLock.ItemIndex := Idx
    else
      ComboBoxCapsLock.ItemIndex := 1; // Default
  finally
    ComboBoxCapsLock.Items.EndUpdate;
  end;

  // ComboBoxLeftWin
  Idx := ComboBoxLeftWin.ItemIndex;
  ComboBoxLeftWin.Items.BeginUpdate;
  try
    ComboBoxLeftWin.Items.Clear;
    ComboBoxLeftWin.Items.Add(Lang[LS_21]);
    ComboBoxLeftWin.Items.Add(Lang[LS_22]);
    if (Idx >= 0) and (Idx < ComboBoxLeftWin.Items.Count) then
      ComboBoxLeftWin.ItemIndex := Idx
    else
      ComboBoxLeftWin.ItemIndex := 1; // Default
  finally
    ComboBoxLeftWin.Items.EndUpdate;
  end;

  // ComboBoxRightCtrl
  Idx := ComboBoxRightCtrl.ItemIndex;
  ComboBoxRightCtrl.Items.BeginUpdate;
  try
    ComboBoxRightCtrl.Items.Clear;
    ComboBoxRightCtrl.Items.Add(Lang[LS_24]);
    ComboBoxRightCtrl.Items.Add(Lang[LS_25]);
    if (Idx >= 0) and (Idx < ComboBoxRightCtrl.Items.Count) then
      ComboBoxRightCtrl.ItemIndex := Idx
    else
      ComboBoxRightCtrl.ItemIndex := 0; // Default
  finally
    ComboBoxRightCtrl.Items.EndUpdate;
  end;
end;

end.
