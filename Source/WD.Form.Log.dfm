object LogForm: TLogForm
  Left = 0
  Top = 0
  Caption = 'LogForm'
  ClientHeight = 411
  ClientWidth = 852
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object LogMemo: TMemo
    Left = 0
    Top = 0
    Width = 852
    Height = 379
    Align = alClient
    TabOrder = 0
    ExplicitHeight = 411
  end
  object ToolsPanel: TPanel
    Left = 0
    Top = 379
    Width = 852
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 381
    object ClearButton: TButton
      Left = 4
      Top = 4
      Width = 109
      Height = 25
      HelpType = htKeyword
      HelpKeyword = 'Caption=8'
      Caption = 'Clear'
      TabOrder = 0
      OnClick = ClearButtonClick
    end
  end
end
