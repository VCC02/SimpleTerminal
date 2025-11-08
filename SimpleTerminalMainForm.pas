{
    Copyright (C) 2025 VCC
    creation date: 05 Nov 2025
    initial release date: 08 Nov 2025

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


unit SimpleTerminalMainForm;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF UNIX}
    LCLIntf, LCLType,
  {$ELSE}
    Windows,
  {$ENDIF}
  SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, PollingFIFO, ExtCtrls, VirtualTrees, ComCtrls, ImgList, Spin, Menus,
  SimpleCOMUI;

type
  TDeviceFlashInfo = record
    Pointer_Size: Integer;
    ProgramFlash_Size: Integer;
    BootFlash_Size: Integer;
    Write_Size: Integer;
    Erase_Size: Integer;
  end;

  { TfrmSimpleTerminalMain }

  TfrmSimpleTerminalMain = class(TForm)
    chkAutoSelectLastCommand: TCheckBox;
    lblBufferSize: TLabel;
    MenuItem_CopySelectedLinesToClipboard: TMenuItem;
    pnlCOMUI: TPanel;
    pmVST: TPopupMenu;
    spnedtBufferSize: TSpinEdit;
    tmrReadFIFO: TTimer;
    btnClearListOfCommands: TButton;
    lblAllReceivedCommands: TLabel;
    tmrStartup: TTimer;
    imglstCmds: TImageList;
    chkAutoScrollToLastCommand: TCheckBox;
    lbeSearchCommand: TLabeledEdit;
    tmrSearch: TTimer;
    procedure chkAutoSelectLastCommandChange(Sender: TObject);
    procedure MenuItem_CopySelectedLinesToClipboardClick(Sender: TObject);
    procedure tmrReadFIFOTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure vstMemCommandsGetText(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
      var CellText: {$IFDEF FPC}string{$ELSE}WideString{$ENDIF});
    procedure vstMemCommandsGetImageIndex(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
      var Ghosted: Boolean; var ImageIndex: Integer);
    procedure vstMemCommandsMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure vstMemCommandsKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnClearListOfCommandsClick(Sender: TObject);
    procedure tmrStartupTimer(Sender: TObject);
    procedure lbeSearchCommandChange(Sender: TObject);
    procedure tmrSearchTimer(Sender: TObject);
  private
    { Private declarations }
    FFIFO: TPollingFIFO;

    FAllCommands: TStringList;
    vstMemCommands: TVirtualStringTree;
    frSimpleCOMUI: TfrSimpleCOMUI;

    procedure LoadSettingsFromIni;
    procedure SaveSettingsToIni;
    procedure CreateRemainingComponents;

    procedure ReadFromFIFO;
    procedure SearchCmd(ASearchText: string);
    procedure CopySelectedLinesToClipboard;

    procedure HandleOnConnectionToCOM;
    procedure HandleOnDisconnectionFromCOM;
    procedure HandleOnExecuteCOMThread(ATerminated: PBoolean);
  public
    { Public declarations }
    property FIFO: TPollingFIFO read FFIFO; //thread safe
  end;

var
  frmSimpleTerminalMain: TfrmSimpleTerminalMain;

implementation


{$IFDEF FPC}
  {$R *.frm}
{$ELSE}
  {$R *.dfm}
{$ENDIF}


uses
  SimpleCOM, IniFiles, Clipbrd;


procedure TfrmSimpleTerminalMain.HandleOnConnectionToCOM;
begin
  tmrReadFIFO.Enabled := True;

  if chkAutoSelectLastCommand.Checked then
    vstMemCommands.TreeOptions.SelectionOptions := vstMemCommands.TreeOptions.SelectionOptions - [toMultiSelect];
end;


procedure TfrmSimpleTerminalMain.HandleOnDisconnectionFromCOM;
begin
  tmrReadFIFO.Enabled := False;
  vstMemCommands.TreeOptions.SelectionOptions := vstMemCommands.TreeOptions.SelectionOptions + [toMultiSelect];
end;


procedure TfrmSimpleTerminalMain.HandleOnExecuteCOMThread(ATerminated: PBoolean);
type
  TArr = array[0..0] of AnsiChar;
var
  TempNrCharsReceived, ActualRead: Integer;
  s, TempCmd: string;
  LongBuffer: string;  //LongBuffer is used as a stream FIFO (adds data on one end, then removes from the other)
  PosCRLF: Integer;
  arr: ^TArr;
begin
  LongBuffer := '';
  repeat
    if COMIsConnected(frSimpleCOMUI.COMName) then
    begin
      TempNrCharsReceived := GetReceivedByteCount(frSimpleCOMUI.ConnHandle);

      if TempNrCharsReceived > 0 then
      begin
        SetLength(s, TempNrCharsReceived);
        arr := @s[1];

        ActualRead := ReceiveDataFromCOM(frSimpleCOMUI.ConnHandle, arr^, TempNrCharsReceived);
        if ActualRead < TempNrCharsReceived then
          SetLength(s, ActualRead);

        LongBuffer := LongBuffer + s;  //keep adding to it
        PosCRLF := Pos({$IFDEF UNIX} #10 {$ELSE} #13#10 {$ENDIF}, LongBuffer); //maybe the config is wrong, so that #13 doesn't make it

        while PosCRLF > 0 do
        begin
          TempCmd := Copy(LongBuffer, 1, PosCRLF - 1);
          if Pos(#0, TempCmd) > 0 then
            Delete(TempCmd, Pos(#0, TempCmd), 1);

          if Length(TempCmd) > 0 then
            FIFO.Put(TempCmd);

          {$IFDEF UNIX}
            Delete(LongBuffer, 1, PosCRLF + 0); //deletes TempCmd and the CRLF after it
            PosCRLF := Pos(#10, LongBuffer);
          {$ELSE}
            Delete(LongBuffer, 1, PosCRLF + 1); //deletes TempCmd and the CRLF after it
            PosCRLF := Pos(#13#10, LongBuffer);
          {$ENDIF}
        end;
      end;
    end;

    Sleep(1);
  until ATerminated^;
end;


procedure TfrmSimpleTerminalMain.lbeSearchCommandChange(Sender: TObject);
begin
  tmrSearch.Enabled := True;
end;


procedure TfrmSimpleTerminalMain.tmrSearchTimer(Sender: TObject);
begin
  tmrSearch.Enabled := False;
  SearchCmd(lbeSearchCommand.Text);
end;


procedure TfrmSimpleTerminalMain.SearchCmd(ASearchText: string);
var
  Node: PVirtualNode;
  IsVisible: Boolean;
  UpperCaseSearchText: string;
begin
  Node := vstMemCommands.GetFirst;
  if Node = nil then
    Exit;

  UpperCaseSearchText := UpperCase(ASearchText);

  repeat
    IsVisible := (ASearchText = '') or (Pos(UpperCaseSearchText, UpperCase(FAllCommands.Strings[Node^.Index])) > 0);

    vstMemCommands.IsVisible[Node] := IsVisible;
    Node := Node^.NextSibling;
  until Node = nil;
end;


procedure TfrmSimpleTerminalMain.btnClearListOfCommandsClick(Sender: TObject);
begin
  FAllCommands.Clear;
  vstMemCommands.RootNodeCount := 0;
  vstMemCommands.Repaint;
end;


procedure TfrmSimpleTerminalMain.LoadSettingsFromIni;
var
  Ini: TMemIniFile;
begin    //opening again, the file from main window, because this window is not created when loading from main
  Ini := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) + 'SimpleTerminal.ini');
  try
    Left := Ini.ReadInteger('Window', 'Left', Left);
    Top := Ini.ReadInteger('Window', 'Top', Top);
    Width := Ini.ReadInteger('Window', 'Width', Width);
    Height := Ini.ReadInteger('Window', 'Height', Height);

    frSimpleCOMUI.ComName := Ini.ReadString('Window', 'ComName', 'COM0');
    frSimpleCOMUI.BaudRate := Ini.ReadInteger('Window', 'Baud', 256000);

    chkAutoScrollToLastCommand.Checked := Ini.ReadBool('Window', 'AutoScrollToLastCommand', chkAutoScrollToLastCommand.Checked);
    chkAutoSelectLastCommand.Checked := Ini.ReadBool('Window', 'AutoSelectLastCommand', chkAutoSelectLastCommand.Checked);
    spnedtBufferSize.Value := Ini.ReadInteger('Window', 'BufferSize', spnedtBufferSize.Value);
  finally
    Ini.Free;
  end;
end;


procedure TfrmSimpleTerminalMain.SaveSettingsToIni;
var
  Ini: TMemIniFile;
begin    //saving again, the file from main window
  Ini := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) + 'SimpleTerminal.ini');
  try
    Ini.WriteInteger('Window', 'Left', Left);
    Ini.WriteInteger('Window', 'Top', Top);
    Ini.WriteInteger('Window', 'Width', Width);
    Ini.WriteInteger('Window', 'Height', Height);

    Ini.WriteString('Window', 'ComName', frSimpleCOMUI.GetCurrentCOMName);
    Ini.WriteInteger('Window', 'Baud', frSimpleCOMUI.BaudRate);

    Ini.WriteBool('Window', 'AutoScrollToLastCommand', chkAutoScrollToLastCommand.Checked);
    Ini.WriteBool('Window', 'AutoSelectLastCommand', chkAutoSelectLastCommand.Checked);
    Ini.WriteInteger('Window', 'BufferSize', spnedtBufferSize.Value);

    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;


procedure TfrmSimpleTerminalMain.CreateRemainingComponents;
var
  NewColum: TVirtualTreeColumn;
begin
  vstMemCommands := TVirtualStringTree.Create(Self);
  vstMemCommands.Parent := Self;

  vstMemCommands.Colors.UnfocusedSelectionColor := clGradientInactiveCaption;
  vstMemCommands.Font.Size := 8;
  vstMemCommands.Font.Height := -11;
  vstMemCommands.Font.Name := 'Tahoma';
  vstMemCommands.Font.Style := [];
  vstMemCommands.Left := 8;
  vstMemCommands.Top := lblAllReceivedCommands.Top + lblAllReceivedCommands.Height + 4;
  vstMemCommands.Width := Width - 16;
  vstMemCommands.Height := ClientHeight - vstMemCommands.Top - 8; //183;
  vstMemCommands.Anchors := [akLeft, akTop, akRight, akBottom];
  vstMemCommands.Header.AutoSizeIndex := 0;
  vstMemCommands.Header.DefaultHeight := 17;
  vstMemCommands.Header.Font.Charset := DEFAULT_CHARSET;
  vstMemCommands.Header.Font.Color := clWindowText;
  vstMemCommands.Header.Font.Height := -11;
  vstMemCommands.Header.Font.Name := 'Tahoma';
  vstMemCommands.Header.Font.Style := [];
  vstMemCommands.Header.Options := vstMemCommands.Header.Options + [hoVisible];
  vstMemCommands.ParentShowHint := False;
  vstMemCommands.PopupMenu := pmVST;
  vstMemCommands.ShowHint := True;
  vstMemCommands.StateImages := imglstCmds;
  vstMemCommands.TabOrder := 8;
  vstMemCommands.TreeOptions.PaintOptions := [toShowButtons, toShowDropmark, toShowRoot, toThemeAware, toUseBlendedImages];
  vstMemCommands.TreeOptions.SelectionOptions := [toFullRowSelect, toRightClickSelect{, toMultiSelect}];
  vstMemCommands.TreeOptions.AutoOptions := [toAutoDropExpand, toAutoScrollOnExpand, toAutoTristateTracking, toAutoDeleteMovedNodes, toDisableAutoscrollOnFocus];
  vstMemCommands.OnGetText := vstMemCommandsGetText;
  vstMemCommands.OnGetImageIndex := vstMemCommandsGetImageIndex;
  vstMemCommands.OnKeyUp := vstMemCommandsKeyUp;
  vstMemCommands.OnMouseUp := vstMemCommandsMouseUp;

  NewColum := vstMemCommands.Header.Columns.Add;
  NewColum.MinWidth := 73;
  NewColum.Position := 0;
  NewColum.Width := 73;
  NewColum.Text := 'Index';

  NewColum := vstMemCommands.Header.Columns.Add;
  NewColum.MinWidth := 10000;
  NewColum.Position := 1;
  NewColum.Width := 10000;
  NewColum.Text := 'Command';

  frSimpleCOMUI := TfrSimpleCOMUI.Create(Self);
  frSimpleCOMUI.Parent := pnlCOMUI;
  frSimpleCOMUI.Left := 0;
  frSimpleCOMUI.Top := 0;
  frSimpleCOMUI.Width := pnlCOMUI.Width;
  frSimpleCOMUI.Height := pnlCOMUI.Height;

  frSimpleCOMUI.OnConnectionToCOM := HandleOnConnectionToCOM;
  frSimpleCOMUI.OnDisconnectionFromCOM := HandleOnDisconnectionFromCOM;
  frSimpleCOMUI.OnExecuteCOMThread := HandleOnExecuteCOMThread;
end;


procedure TfrmSimpleTerminalMain.FormCreate(Sender: TObject);
begin
  CreateRemainingComponents;

  FFIFO := TPollingFIFO.Create;
  FAllCommands := TStringList.Create;

  tmrStartup.Enabled := True;
end;


procedure TfrmSimpleTerminalMain.FormDestroy(Sender: TObject);
begin
  tmrReadFIFO.Enabled := False;
  FreeAndNil(FFIFO);
  FreeAndNil(FAllCommands);

  try
    SaveSettingsToIni;
  except
  end;
end;


procedure TfrmSimpleTerminalMain.FormShow(Sender: TObject);
begin
  //
end;


procedure TfrmSimpleTerminalMain.vstMemCommandsGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: {$IFDEF FPC}string{$ELSE}WideString{$ENDIF});
begin
  case Column of
    0: CellText := IntToStr(Node^.Index); 
    1: CellText := '"' + FAllCommands.Strings[Node^.Index] + '"';
  end;
end;


procedure TfrmSimpleTerminalMain.vstMemCommandsGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
begin
  if Column = 1 then
    ImageIndex := 0;
end;


procedure TfrmSimpleTerminalMain.vstMemCommandsMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: PVirtualNode;
begin
  Node := vstMemCommands.GetFirstSelected;
  if Node = nil then
    Exit;

  //repeat
  //  if vstMemCommands.Selected[Node] then
  //    ;
  //
  //  Node := Node^.NextSibling;
  //until Node = nil;
end;


procedure TfrmSimpleTerminalMain.vstMemCommandsKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = Ord('C') then
    if ssCtrl in Shift then
      CopySelectedLinesToClipboard;
end;


procedure TfrmSimpleTerminalMain.ReadFromFIFO;
var
  FIFOContent: TStringList;
  i, MaxBufferSize: Integer;
begin
  if FFIFO.GetLength = 0 then
    Exit;

  FIFOContent := TStringList.Create;
  try
    FFIFO.PopAll(FIFOContent);
    FAllCommands.AddStrings(FIFOContent);

    MaxBufferSize := spnedtBufferSize.Value;
    if FAllCommands.Count > MaxBufferSize then
    begin
      for i := 0 to FAllCommands.Count - MaxBufferSize - 1 do
        FAllCommands.Delete(0);
    end;

    vstMemCommands.BeginUpdate;
    try
      vstMemCommands.RootNodeCount := FAllCommands.Count;

      if FAllCommands.Count > 0 then
      begin
        if chkAutoScrollToLastCommand.Checked then
          vstMemCommands.ScrollIntoView(vstMemCommands.GetLast, False);

        if chkAutoSelectLastCommand.Checked then
          vstMemCommands.Selected[vstMemCommands.GetLast] := True;
      end;
    finally
      vstMemCommands.EndUpdate;
    end;

    lblAllReceivedCommands.Caption := 'All received commands (' + IntToStr(FAllCommands.Count) + '):';
  finally
    FIFOContent.Free;
  end;
end;


procedure TfrmSimpleTerminalMain.tmrReadFIFOTimer(Sender: TObject);
begin
  ReadFromFIFO;
end;


procedure TfrmSimpleTerminalMain.CopySelectedLinesToClipboard;
var
  Node: PVirtualNode;
  s: string;
begin
  Node := vstMemCommands.GetFirstSelected;
  if Node = nil then
    Exit;

  s := '';
  repeat
    if vsSelected in Node^.States then
      s := s + FAllCommands.Strings[Node^.Index] + #13#10;

    Node := Node^.NextSibling;
  until Node = nil;

  if s > '' then
    Delete(s, Length(s) - 1, 2);

  Clipboard.AsText := s;
end;


procedure TfrmSimpleTerminalMain.MenuItem_CopySelectedLinesToClipboardClick(
  Sender: TObject);
begin
  CopySelectedLinesToClipboard;
end;


procedure TfrmSimpleTerminalMain.chkAutoSelectLastCommandChange(Sender: TObject);
begin
  if chkAutoSelectLastCommand.Checked then
    vstMemCommands.TreeOptions.SelectionOptions := vstMemCommands.TreeOptions.SelectionOptions - [toMultiSelect];
end;


procedure TfrmSimpleTerminalMain.tmrStartupTimer(Sender: TObject);
begin
  tmrStartup.Enabled := False;

  frSimpleCOMUI.UpdateListOfCOMPorts;
  LoadSettingsFromIni;
end;

end.
