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

  WD.Types.Actions;

type

  TSettingsForm = class(TForm)
    ButtonCancel: TButton;
    ButtonOK: TButton;
    ComboBoxCapsLock: TComboBox;
    ComboBoxLeftWin: TComboBox;
    ComboBoxRightCtrl: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
  end;

implementation

{$R *.dfm}

end.
