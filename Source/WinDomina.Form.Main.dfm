object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'WinDomina'
  ClientHeight = 450
  ClientWidth = 868
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object TrayIcon: TTrayIcon
    Hint = 'WinDomina'
    BalloonFlags = bfInfo
    Icons = TrayImageList
    PopupMenu = TrayPopupMenu
    Visible = True
    OnDblClick = TrayIconDblClick
    Left = 760
    Top = 376
  end
  object TrayImageList: TImageList
    ColorDepth = cd32Bit
    Height = 32
    Width = 32
    Left = 744
    Top = 312
    Bitmap = {
      494C010102000800500020002000FFFFFFFF2110FFFFFFFFFFFFFFFF424D3600
      0000000000003600000028000000800000002000000001002000000000000040
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000002D2D2D6CFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA060606280000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00002222225EBCBCBCDB00000000000000000000000000000000000000000000
      000000000000000005250000A0CA0000AED30000AED30000A8CF00000D3B0000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000A35000069A400000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000838383B7FDFDFDFEFFFFFFFFFFFFFFFFFFFFFFFF0303031F0000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000D0D
      0D3BF5F5F5FACDCDCDE500000000000000000000000000000000000000000000
      0000000000000000306F0000F5FA0202FFFF0202FFFF0000FFFF00001C560000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      031C0000D8EB0000DCED00000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000001E1E1E1F0FFFFFFFFFFFFFFFFFFFFFFFFEBEBEBF5000000010000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000000000303031FDCDC
      DCEDFFFFFFFF838383B700000000000000000000000000000000000000000000
      000000000000000070A90101F9FC0505FFFF0404FFFF0000FFFF0000062A0000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000090000
      A8CF0303FFFF000093C200000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000005050524FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA1A1A1CB000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000CB3B3B3D6F5F5
      F5FAF5F5F5FA4848488800000000000000000000000000000000000000000000
      0000000000000000CDE50202FFFF0505FFFF0303FFFF0000F5FA000000050000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000001000075AD0404
      F5FA0C0CF9FC0000569400000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00002121215CF9F9F9FCFFFFFFFFFFFFFFFFF5F5F5FA5C5C5C99000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000027F7F7FB4F5F5F5FAFFFF
      FFFFF9F9F9FC1E1E1E5900000000000000000000000000000000000000000000
      0000000002170000FFFF0404FFFF0505FFFF0202FFFF0000B7D8000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000040800202F9FC1111
      FFFF1010F5FA0000296700000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000054545493F3F3F3F9FFFFFFFFFFFFFFFFF3F3F3F92E2E2E6D000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000049494989F9F9F9FCFFFFFFFFFFFF
      FFFFFDFDFDFE0101011600000000000000000000000000000000000000000000
      00000000174E0000FDFE0505FFFF0505FFFF0101FBFD00006AA5000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000001A530000FDFE0D0DFFFF1D1D
      FFFF0B0BFFFF0000042300000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000ABABABD1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF11111143000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000002222225EFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFB0B0B0D40000000000000000000000000000000000000000000000000000
      0000000045850000F1F80505FFFF0505FFFF0000F1F800003A7A000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000A330000F1F80707FFFF1A1AFFFF2424
      FFFF0404CDE50000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0009F9F9F9FCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF04040423000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000F0F0F3FF7F7F7FBFDFDFDFEFFFFFFFFFFFFFFFFF3F3
      F3F9474747870000000000000000000000000000000000000000000000000000
      0000000092C10101FFFF0505FFFF0505FFFF0000F9FC00001E59000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000031D0000D6EA0404F9FC1414FFFF2929FFFF2020
      F7FB000058960000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000D0D
      0D3BFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFDFDFE00000006000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000006060628E3E3E3F1FBFBFBFDFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFF090909320000000000000000000000000000000000000000000000000000
      00020000EBF50303FFFF0505FFFF0505FFFF0000FFFF00000D3A000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000E0000B5D70101F3F90F0FFFFF2424FFFF2F2FFFFF0F0F
      FDFE000013460000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000003333
      3373F3F3F3F9FFFFFFFFFFFFFFFFFFFFFFFFD6D6D6EA00000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000001010114C6C6C6E1F7F7F7FBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB7B7
      B7D8000000000000000000000000000000000000000000000000000000000000
      072C0000FFFF0404FFFF0505FFFF0404FFFF0000FFFF0000021A000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000500008CBD0101F5FA0A0AFFFF1C1CFFFF3333FFFF2C2CFFFF0303
      D4E9000000030000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000007474
      74ACF9F9F9FCFFFFFFFFFFFFFFFFFFFFFFFFA3A3A3CC00000000000000000000
      0000000000000000000000000000000000000000000000000000000000000101
      0110ADADADD2F5F5F5FAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7F7FB3030
      306F000000000000000000000000000000000000000000000000000000000000
      26630000F5FA0505FFFF0505FFFF0303FFFF0000F7FB00000002000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0002000069A40000F7FB0707FFFF1616FFFF2F2FFFFF3737FFFF1B1BF5FA0000
      4484000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000000000000CFCF
      CFE6FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF747474AC00000000000000000000
      00000000000000000000000000000000000000000000000000000000000CA1A1
      A1CBF5F5F5FAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF3F3F3F90101
      0114000000000000000000000000000000000000000000000000000000000000
      5C990101F5FA0505FFFF0505FFFF0202FFFF0000CFE600000000000000000000
      0000000000000000000000000000000000000000000000000000000000010000
      5C990000F9FC0606FFFF1111FFFF2828FFFF3939FFFF2F2FFFFF0707FDFE0000
      0524000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000001010110FDFD
      FDFEFFFFFFFFFFFFFFFFFFFFFFFFF9F9F9FC6262629E00000000000000000000
      000000000000000000000000000000000000000000000000000A939393C2F5F5
      F5FAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA585858960000
      0000000000000000000000000000000000000000000000000000000000000000
      A9D00202FFFF0505FFFF0505FFFF0202FFFF0000B7D800000000000000000000
      000000000000000000000000000000000000000000000000000000004D8C0000
      F9FC0505FFFF0F0FFFFF2323FFFF3838FFFF3939FFFF1D1DF7FB00007BB10000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000000000F0F0F3FFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7F7FB5959599700000000000000000000
      00000000000000000000000000000000000001010116A4A4A4CDF5F5F5FAFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9F9F9FC040404200000
      0000000000000000000000000000000000000000000000000000000000030000
      F1F80303FFFF0505FFFF0505FFFF0202FFFF0000A6CE00000000000000000000
      0000000000000000000000000000000000000000000400005D9A0000FBFD0505
      FFFF0E0EFFFF1F1FFFFF3636FFFF3D3DFFFF2F2FFFFF0808FFFF00000A340000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000000002F2F2F6EF3F3
      F3F9FFFFFFFFFFFFFFFFFFFFFFFFFBFBFBFD676767A200000000000000000000
      000000000000000000000000000005050527C8C8C8E2F5F5F5FAFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA696969A4000000000000
      0000000000000000000000000000000000000000000000000000000006280000
      FFFF0404FFFF0505FFFF0505FFFF0202FFFF0000B7D800000000000000000000
      00000000000000000000000000000000000C000086B90000F7FB0606FFFF0F0F
      FFFF2020FFFF3535FFFF3E3EFFFF3737FFFF1A1AF7FB00008CBD000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000000006060609DF7F7
      F7FBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA0A0A0CA00000000000000000000
      000000000000000000012323235FE9E9E9F4F7F7F7FBFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA04040422000000000000
      000000000000000000000000000000000000000000000000000000001D570000
      F9FC0505FFFF0505FFFF0505FFFF0303FFFF0000E5F200000001000000000000
      00000000000000000000000009300000B8D90101F5FA0909FFFF1414FFFF2525
      FFFF3737FFFF3F3FFFFF3B3BFFFF2525FFFF0404FDFE00000B36000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000AEAEAED3FFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7F7FB14141448000000070101
      01121D1D1D57A4A4A4CDFDFDFDFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA4646468600000000000000000000
      0000000000000000000000000000000000000000000000000000000046860000
      F1F80505FFFF0505FFFF0505FFFF0404FFFF0000FFFF00001B54000000000000
      00000000072D00005E9B0000FBFD0505F7FB0F0FFFFF1C1CFFFF2E2EFFFF3B3B
      FFFF4040FFFF3B3BFFFF2B2BFFFF0C0CF3F900006AA500000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000004F5F5F5FAFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7F7FBFFFFFFFFFFFFFFFFFFFF
      FFFFFBFBFBFDF9F9F9FCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFDFDFDFED8D8D8EB0000000D00000000000000000000
      0000000000000000000000000000000000000000000000000000000086B90101
      FFFF0505FFFF0505FFFF0505FFFF0505FFFF0202F9FC0000FFFF0000E9F40000
      E9F40000FFFF0404F3F90D0DFFFF1A1AFFFF2929FFFF3737FFFF3E3EFFFF3F3F
      FFFF3939FFFF2A2AFFFF1212FFFF0000EFF70000021B00000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000707072BFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFDFDFDFE1E1E1E580000000000000000000000000000
      00000000000000000000000000000000000000000000000000000000D8EB0202
      FFFF0505FFFF0505FFFF0505FFFF0505FFFF0505FFFF0404FFFF0404FFFF0707
      FFFF0E0EFFFF1A1AFFFF2929FFFF3535FFFF3A3AFFFF3B3BFFFF3838FFFF2F2F
      FFFF2020FFFF1010FFFF0101F9FC000035750000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000001B1B1B54FBFBFBFDFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFF5F5F5FA757575AD000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000001100000FFFF0303
      FFFF0505FFFF0505FFFF0505FFFF0505FFFF0606FFFF0909FFFF0F0FFFFF1A1A
      FFFF2828FFFF3333FFFF3737FFFF3535FFFF2E2EFFFF2424FFFF1A1AFFFF1212
      FFFF0B0BFFFF0202F5FA0000A1CB000000030000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000034343474F1F1F1F8FFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFBFBFBFDDCDCDCED01010114000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000009300000FFFF0404
      FFFF0505FFFF0505FFFF0505FFFF0808FFFF0E0EFFFF1919FFFF2727FFFF3333
      FFFF3535FFFF3030FFFF2424FFFF1818FFFF1010FFFF0C0CFFFF0909FFFF0606
      FFFF0202FFFF0000F1F800000526000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000057575795F5F5F5FAFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFDFDFDFE1414144900000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000019510000FBFD0505
      FFFF0505FFFF0606FFFF0A0AFFFF1515FFFF2525FFFF3333FFFF3737FFFF3131
      FFFF2222FFFF1515FFFF0C0CFFFF0808FFFF0606FFFF0505FFFF0505FFFF0303
      FFFF0000FBFD00002B6900000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000878787BAFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9F9
      F9FC3D3D3D7D0000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000032720000F1F80505
      FFFF0606FFFF0B0BFFFF1A1AFFFF2E2EFFFF3838FFFF3636FFFF2828FFFF1818
      FFFF0D0DFFFF0707FFFF0505FFFF0505FFFF0505FFFF0505FFFF0404FFFF0000
      F5FA00006CA60000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000BFBFBFDDFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FA7D7D
      7DB3000000010000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000053920101F3F90505
      FFFF0909FFFF1919FFFF3030FFFF3A3AFFFF3232FFFF2020FFFF1010FFFF0808
      FFFF0606FFFF0505FFFF0505FFFF0505FFFF0505FFFF0505FFFF0000F5FA0000
      ABD1000000080000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000E9E9E9F4FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FAA6A6A6CE0000
      000C000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000076AE0101FFFF0707
      FFFF1212FFFF2B2BFFFF3A3AFFFF3232FFFF1A1AFFFF0D0DFFFF0707FFFF0505
      FFFF0505FFFF0505FFFF0505FFFF0505FFFF0505FFFF0000F5FA0000CBE40000
      021B000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000F9F9F9FCFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FAB7B7B7D8010101120000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000008ABC0303FFFF0C0C
      FFFF2121FFFF3838FFFF3838FFFF2020FFFF0D0DFFFF0606FFFF0505FFFF0505
      FFFF0505FFFF0505FFFF0505FFFF0505FFFF0101F7FB0000D8EB000005240000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000E9E9E9F4FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFF5F5F5FABCBCBCDB02020219000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000007CB20404FFFF1616
      FFFF3232FFFF3C3CFFFF2E2EFFFF1313FFFF0707FFFF0505FFFF0505FFFF0505
      FFFF0505FFFF0505FFFF0505FFFF0000F5FA0000DCED0000072D000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000909090C0F9F9F9FCFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFF7F7F7FB9B9B9BC70101011100000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000003E7E0808F3F92424
      FFFF3A3AFFFF3838FFFF1F1FFFFF0B0BFFFF0505FFFF0505FFFF0505FFFF0505
      FFFF0505FFFF0404FFFF0000F5FA0000C3DF0000042200000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000001A1A1A52FDFDFDFEFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFDFDFDFEFDFDFDFE6C6C6CA6000000080000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000021B0D0DF5FA2F2F
      FFFF3D3DFFFF2F2FFFFF1313FFFF0707FFFF0505FFFF0505FFFF0505FFFF0505
      FFFF0303FFFF0000F9FC000098C5000001140000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000000000018F8F8FBFF5F5
      F5FAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF3F3
      F3F9E7E7E7F31E1E1E5900000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000050544843232
      F9FC3737FFFF1F1FFFFF0B0BFFFF0505FFFF0505FFFF0505FFFF0303FFFF0000
      F5FA0000F9FC0000387800000003000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000001010114ADAD
      ADD2F7F7F7FBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF3F3F3F9F7F7F7FB5C5C
      5C990202021B0000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000030B0B
      78AF2222FBFD0E0EFDFE0505FFFF0303FFFF0202FFFF0000F3F90000FDFE0000
      7FB40000072D0000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000938383878BABABADAF7F7F7FBEFEFEFF7969696C43B3B3B7B0303031F0000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00010000215D0000A3CC0000F3F90000F5FA0000B0D400004989000009310000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000424D3E000000000000003E000000
      2800000080000000200000000100010000000000000200000000000000000000
      000000000000000000000000FFFFFF0000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000}
  end
  object TrayPopupMenu: TPopupMenu
    Left = 808
    Top = 312
    object ToggleDominaModeMenuItem: TMenuItem
      Action = ToggleDominaModeAction
      Default = True
    end
    object CloseMenuItem: TMenuItem
      Action = CloseAction
    end
  end
  object ActionList: TActionList
    Left = 496
    Top = 352
    object CloseAction: TAction
      Caption = 'Close'
      HelpKeyword = 'Caption=1'
      OnExecute = CloseActionExecute
    end
    object ToggleDominaModeAction: TAction
      Caption = 'Toggle dominate mode'
      OnExecute = ToggleDominaModeActionExecute
    end
  end
end
