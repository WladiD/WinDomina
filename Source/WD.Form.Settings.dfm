object SettingsForm: TSettingsForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 160
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poMainFormCenter
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 20
    Width = 119
    Height = 13
    Caption = 'Double tap on CapsLock:'
  end
  object Label2: TLabel
    Left = 16
    Top = 50
    Width = 111
    Height = 13
    Caption = 'Double tap on LeftWin:'
  end
  object Label3: TLabel
    Left = 16
    Top = 80
    Width = 116
    Height = 13
    Caption = 'Double tap on RightCtrl:'
  end
  object ComboBoxCapsLock: TComboBox
    Left = 210
    Top = 17
    Width = 230
    Height = 21
    Style = csDropDownList
    TabOrder = 0
    Items.Strings = (
      'Do nothing'
      'Activate WD (Default)'
      'Activate WD and ignore key')
  end
  object ComboBoxLeftWin: TComboBox
    Left = 210
    Top = 47
    Width = 230
    Height = 21
    Style = csDropDownList
    TabOrder = 1
    Items.Strings = (
      'Do nothing'
      'Activate WD (Default)')
  end
  object ComboBoxRightCtrl: TComboBox
    Left = 210
    Top = 77
    Width = 230
    Height = 21
    Style = csDropDownList
    TabOrder = 2
    Items.Strings = (
      'Do nothing (Default)'
      'Translate to ContextMenuKey')
  end
  object ButtonOK: TButton
    Left = 280
    Top = 120
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 3
  end
  object ButtonCancel: TButton
    Left = 365
    Top = 120
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
end
