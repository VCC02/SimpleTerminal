object frmSimpleTerminalMain: TfrmSimpleTerminalMain
  Left = 43
  Height = 363
  Top = 57
  Width = 972
  Caption = 'Simple Terminal'
  ClientHeight = 363
  ClientWidth = 972
  Color = clBtnFace
  Constraints.MinHeight = 363
  Constraints.MinWidth = 972
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  LCLVersion = '8.4'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  object lblAllReceivedCommands: TLabel
    Left = 8
    Height = 13
    Top = 89
    Width = 177
    AutoSize = False
    Caption = 'All received commands:'
  end
  object btnClearListOfCommands: TButton
    Left = 312
    Height = 25
    Top = 16
    Width = 140
    Caption = 'Clear list of commands'
    TabOrder = 0
    OnClick = btnClearListOfCommandsClick
  end
  object chkAutoScrollToLastCommand: TCheckBox
    Left = 728
    Height = 17
    Hint = 'Scrolls the list to the last item.'
    Top = 16
    Width = 146
    Caption = 'Autoscroll to last command'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 1
  end
  object lbeSearchCommand: TLabeledEdit
    Left = 464
    Height = 21
    Top = 16
    Width = 256
    EditLabel.Height = 13
    EditLabel.Width = 256
    EditLabel.Caption = 'Search command'
    TabOrder = 2
    OnChange = lbeSearchCommandChange
  end
  object chkAutoSelectLastCommand: TCheckBox
    Left = 728
    Height = 17
    Top = 40
    Width = 137
    Caption = 'Autoselect last command'
    TabOrder = 3
    OnChange = chkAutoSelectLastCommandChange
  end
  object spnedtBufferSize: TSpinEdit
    Left = 888
    Height = 21
    Hint = 'Number of lines'
    Top = 35
    Width = 74
    MaxValue = 1000000
    MinValue = 10
    ParentShowHint = False
    ShowHint = True
    TabOrder = 4
    Value = 10000
  end
  object lblBufferSize: TLabel
    Left = 888
    Height = 13
    Top = 16
    Width = 51
    Caption = 'Buffer size'
  end
  object pnlCOMUI: TPanel
    Left = 0
    Height = 90
    Top = 0
    Width = 310
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 5
  end
  object tmrReadFIFO: TTimer
    Enabled = False
    Interval = 100
    OnTimer = tmrReadFIFOTimer
    Left = 120
    Top = 120
  end
  object tmrStartup: TTimer
    Enabled = False
    Interval = 10
    OnTimer = tmrStartupTimer
    Left = 48
    Top = 120
  end
  object imglstCmds: TImageList
    Left = 388
    Top = 156
    Bitmap = {
      4C7A0100000010000000100000005F0000000000000078DA63606060B0ED95FE
      0FC27C27FFFF2785CD80A4971CFDC8F8C522069230B279200C123B7CF8305118
      A416A60FD97E901CD04BFFF74D2A20A81F9BFB417220BDA4E8A7B6FB89D58FCB
      FDA4EA1F753F65E997D2FCC34061FE0500E9F99E37
    }
  end
  object tmrSearch: TTimer
    Enabled = False
    Interval = 200
    OnTimer = tmrSearchTimer
    Left = 48
    Top = 216
  end
  object pmVST: TPopupMenu
    Left = 464
    Top = 120
    object MenuItem_CopySelectedLinesToClipboard: TMenuItem
      Caption = 'Copy selected lines to clipboard'
      OnClick = MenuItem_CopySelectedLinesToClipboardClick
    end
  end
end
