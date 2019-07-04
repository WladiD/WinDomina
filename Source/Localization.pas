unit Localization;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.IniFiles,
  System.RegularExpressionsCore,
  Vcl.StdCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Menus,
  Vcl.Forms,
  Vcl.ActnList,
  Vcl.Consts,

  ProcedureHook;

type
  {**
   * Einfache Schnittstelle, die Objekten ermöglicht eine Translate-Prozedur zu implementieren,
   * die dann beim durchlaufen von TLang.Translate aufgerufen wird.
   *}
  ITranslate = interface
    ['{D5DE8131-BC1E-49D3-9AF4-86A35D557FA7}']
    {**
     * Sagt aus, ob das jeweilige Objekt bereit für die Übersetzung ist
     *
     * Wenn es FALSE liefert, muss die Prozedur OnReadyForTranslate entsprechend implementiert
     * werden.
     *}
    function IsReadyForTranslate: Boolean;
    {**
     * Ereignis-Registrierung
     *
     * Diese Methode kann auch leer sein, wenn IsReadyForTranslate generell TRUE liefert. Das
     * Objekt muss sich das übergebene NotifyEvent merken und dieses Aufrufen, wenn es für
     * die Übersetzung bereit ist.
     *}
    procedure OnReadyForTranslate(NotifyEvent: TNotifyEvent);
    {**
     * Diese Methode ist dafür gedacht, spezifische Elemente zu übersetzen, die z.B. nicht
     * über den TComponent-Owner-Mechanismus erreichbar sind.
     *}
    procedure Translate;
  end;

  TLangEntry = record
    Code: string;
    InternationalName: string;
    LocalName: string;
  end;

  TLangEntries = array of TLangEntry;
  TNameHashedStringList = class;

  TLang = class(TComponent)
  protected
    type
    TMenuKeyCap = (mkcBkSp, mkcTab, mkcEsc, mkcEnter, mkcSpace, mkcPgUp, mkcPgDn, mkcEnd,
      mkcHome, mkcLeft, mkcUp, mkcRight, mkcDown, mkcIns, mkcDel, mkcShift, mkcCtrl, mkcAlt);

    const
    LangFileNameFormat: string = 'Lang.%s.ini';

    InfoSection: string = 'Info';
    ConstsSection: string = 'Consts';
    StringsSection: string = 'Strings';
    MessagesSection: string = 'Messages';

    var
    FLangCode: string;
    FLangInternationalName: string;
    FLangLocalName: string;
    FMenuKeyCaps: array[TMenuKeyCap] of string;
    {**
     * Runtime translate of some resource strings of Delphi's Consts.pas
     *
     * @see TLang.SetLangCode.HookConsts
     *}
    FConstResources: TStringDynArray;
    FStrings: TStringList;
    FMessages: TStringList;
    FMessagesOffset: Integer;
    FConsts: TStringList;
    FInitialized: Boolean;
    FNumberPCRE: TPerlRegEx;
    FLangPath: string;

    procedure SetLangCode(NewLangCode: string);
    function GetString(Index: Integer): string;
    function GetConst(Name: string): string;

    procedure ReadyForTranslateEvent(Sender: TObject);

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    class function GetSystemLangCode: string;

    function GetLangFileName(LangCode: string; IncludePath: Boolean = True): string;
    function GetAvailableLanguages: TLangEntries;
    function IsLanguageAvailable(LangCode: string): Boolean;

    function CountFormat(StringIndex, Count: Integer): string;
    function ShortCutToText(ShortCut: TShortCut): string;

    function Translate(Incoming: string): string; overload;
    procedure Translate(ComponentHolder: TComponent); overload;
    procedure TranslateApplication;

    {**
     * Language code by the ISO639-1 standard
     *}
    property LangCode: string read FLangCode write SetLangCode;
    {**
     * International name of the language
     *}
    property LangInternationalName: string read FLangInternationalName;
    {**
     * The native name of the language
     *}
    property LangLocalName: string read FLangLocalName;

    property LangPath: string read FLangPath;
    {**
     * Common strings
     *}
    property Strings[Index: Integer]: string read GetString; default;
    {**
     * Named constants
     *}
    property Consts[Name: string]: string read GetConst;
  end;

  TNameHashedStringList = class(TStringList)
  private
    FNameHash: TStringHash;
    FNameHashValid: Boolean;

    procedure UpdateNameHash;
  protected
    procedure Changed; override;
  public
    destructor Destroy; override;
    function IndexOfName(const Name: string): Integer; override;
  end;

{**
 * Initializes the global TLang instance Lang
 *
 * @param WorkPath Pass a path where you have write permissions.
 *        Currently there is only the file "LangInfo.ini" saved, which contains some informations
 *        for faster access and language file change detections.
 * @param LangPath Path where all your language files are located
 * @param LangCode Optional. ISO639-1 standard. Initialize with a specific language.
 *        If no LangCode is passed:
 *        - Language file, which match the system language, is used
 *        - If no language file exists for the system language, so English (en) will be used.
 *}
procedure InitializeLang(WorkPath, LangPath: string; LangCode: string = '');

function CountFormat(const Conditions: string; Count: Integer): string;

var
  {**
   * Global TLang instance
   *
   * Initialize it with the procedure InitializeLang.
   * Don't free it manually, it is destroyed by TApplication automatically!
   *}
  Lang: TLang;

implementation

var
  OriginShortCutToText: TOverWrittenData;

procedure InitializeLang(WorkPath, LangPath, LangCode: String);
const
  DefaultLangCode: string = 'en';
begin
  if Assigned(Lang) then
    Lang.Free;

  Lang := TLang.Create(nil);
  Lang.FLangPath := IncludeTrailingPathDelimiter(LangPath);

  if LangCode = '' then
    LangCode := TLang.GetSystemLangCode;
  if (LangCode <> DefaultLangCode) and not Lang.IsLanguageAvailable(LangCode) then
    LangCode := DefaultLangCode;

  Lang.LangCode := LangCode;
end;

procedure HookResourceString(RS: PResStringRec; NewString: PChar);
var
  OldProtect: DWORD;
begin
  VirtualProtect(RS, SizeOf(RS^), PAGE_EXECUTE_READWRITE, @OldProtect);
  RS^.Identifier := Integer(NewString);
  VirtualProtect(RS, SizeOf(RS^), OldProtect, @OldProtect);
end;

{**
 * Formatiert eine Anzahl
 *
 * Der String mit dem StringIndex muss dem SDF-Format (CSV) entsprechen, d.h.:
 *
 * Jede Anweisung, die ein Leerzeichen [ ], Komma [,] oder Anführungsstriche ["] enthält, wird in
 * Anführungsstriche eingeschlossen. Eventuell in der Anweisung vorkommende Anführungsstriche werden
 * verdoppelt. Jede Anweisung wird mit einem Komma [,] oder einem Leerzeichen [ ] voneinander
 * getrennt.
 *
 * Jede Anweisung beginnt mit einer Operation gefolgt vom Gleichheitszeichen [=]. Vor und nach dem
 * Gleichheitszeichen sollten keine Leerzeichen stehen.
 *
 * Nach dem Gleichheitszeichen folgt der Ausgabestring, der optional einen für die
 * Delphi-Format-Funktion gültigen Format-String (%d, %u oder %x) enthält.
 *
 * Operationen
 * -----------
 * eq[Zahl] = Gleich (Equal)
 * gt[Zahl] = Größer als (Greater then)
 * lt[Zahl] = Kleiner als (Lower then)
 * else     = Sonstiger Fall, wird beim erreichen sofort verwendet, restliche Anweisungen werden
 *            nicht berücksichtigt.
 *
 * Die Anweisungen werden von Links nach Rechts verarbeitet, was als erstes zutrifft, wird
 * verwendet.
 *
 * Beispiele:
 * "eq0=Keine Dateien ausgewählt","eq1=Eine Datei ausgewählt","else=%d Dateien ausgewählt"
 * "lt0=Fehler","eq100=Genau ein Hundert","gt100=Über ein Hundert","lt100=Weniger als ein Hundert"
 *}
function CountFormat(const Conditions: string; Count: Integer): string;
var
  ConditionList: TStringList;
  ConditionIndex: Integer;

  {**
   * Determines, whether the passed condition match the count
   *}
  function ConditionMatch(Condition: string): Boolean;
  const
    // Special operators are handled before basics
    OPElse = 'else';
    // Basic operators are fixed length
    BasicOPLength = 2;
    OPEqual = 'eq';
    OPGreaterThen = 'gt';
    OPLowerThen = 'lt';
  var
    Operation: string;
    CountString: string;
    MatchCount: Integer;
  begin
    Condition := Trim(LowerCase(Condition));
    if (Condition = '') or (Length(Condition) < 3) then
      Exit(False);
    if Condition = OPElse then
      Exit(True);
    Operation := Copy(Condition, 1, BasicOPLength);
    CountString := Copy(Condition, BasicOPLength + 1, Length(Condition) - BasicOPLength);
    if not TryStrToInt(CountString, MatchCount) then
      Exit(False);

    Result := ((Operation = OPEqual) and (Count = MatchCount)) or
      ((Operation = OPLowerThen) and (Count < MatchCount)) or
      ((Operation = OPGreaterThen) and (Count > MatchCount));
  end;

  {**
   * Determines, whether the passed string contains valid format string for use the count with
   * Delphi's Format function.
   *}
  function HasValidFormatString(const Output: string): Boolean;
  var
    MatchPCRE: TPerlRegEx;
  begin
    {**
     * The percent sign must be there in each case, so we do a short check
     *}
    if Pos('%', Output) = 0 then
      Exit(False);
    MatchPCRE := TPerlRegEx.Create;
    try
      MatchPCRE.Options := [preCaseLess];
      MatchPCRE.Compile('%[\-\d\.:]*[dux]');
      Result := MatchPCRE.Match(Output);
    finally
      MatchPCRE.Free;
    end;
  end;

begin
  Result := '';

  ConditionList := TStringList.Create;
  try
    ConditionList.CommaText := Conditions;
    {**
     * Search for a matching condition
     *}
    for ConditionIndex := 0 to ConditionList.Count - 1 do
      if ConditionMatch(ConditionList.Names[ConditionIndex]) then
      begin
        Result := ConditionList.ValueFromIndex[ConditionIndex];
        Break;
      end;
    {**
     * Pass the count to Delphi's Format, if possible
     *}
    if (Result <> '') and HasValidFormatString(Result) then
      Result := Format(Result, [Count]);
  finally
    ConditionList.Free;
  end;
end;

{** TLang **}

constructor TLang.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FStrings := TStringList.Create;
  FMessages := TStringList.Create;
  FConsts := TNameHashedStringList.Create;
  FNumberPCRe := TPerlRegEx.Create;
  FNumberPCRE.Compile('(?(?=\\\d)(?P<Escaped>\\(?P<EscapedNumber>\d+))|(?P<Number>\d+))');
end;

destructor TLang.Destroy;
begin
  FStrings.Free;
  FMessages.Free;
  FConsts.Free;
  FNumberPCRE.Free;

  inherited Destroy;
end;

function TLang.CountFormat(StringIndex, Count: Integer): string;
begin
  Result := Localization.CountFormat(Strings[StringIndex], Count);
end;

{**
 * Retrieve a array, that contain main information of available languages
 *}
function TLang.GetAvailableLanguages: TLangEntries;
var
  SR: TSearchRec;
  LangINI: TMemIniFile;
  LangINIFileName, LangCode, LangLocalName, LangIntlName: string;
  Index: Integer;
begin
  if FindFirst(GetLangFileName('*'), 0, SR) <> 0 then
    Exit;

  try
    repeat
      SR.Name := LangPath + SR.Name;
      LangINIFileName := ExtractFileName(SR.Name);

      LangINI := TMemIniFile.Create(SR.Name, TEncoding.UTF8);
      try
        LangCode := LangINI.ReadString(InfoSection, 'LangCode', '');
        LangLocalName := LangINI.ReadString(InfoSection, 'LocalName', '');
        LangIntlName := LangINI.ReadString(InfoSection, 'InternationalName', '');
      finally
        LangINI.Free;
      end;

      {**
       * Finally we can add one language to our result array
       *}
      Index := Length(Result);
      SetLength(Result, Index + 1);
      Result[Index].Code := LangCode;
      Result[Index].InternationalName := LangIntlName;
      Result[Index].LocalName := LangLocalName;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function TLang.GetConst(Name: string): string;
begin
  Result:=FConsts.Values[Name];
end;

function TLang.GetLangFileName(LangCode: string; IncludePath: Boolean): string;
begin
  if IncludePath then
    Result:=FLangPath
  else
    Result:='';
  Result:=Result + Format(LangFileNameFormat, [LangCode]);
end;

{**
 * Liefert einen String anhand eines Index
 *}
function TLang.GetString(Index: Integer): string;
begin
  if Index >= FMessagesOffset then
    Result:=FMessages[Index - FMessagesOffset]
  else
    Result:=FStrings[Index];
end;

{**
 * Determines the system language code ISO 639-1
 *}
class function TLang.GetSystemLangCode: string;
begin
  {**
   * Extend it as you need
   *}
  case GetUserDefaultLangID and $00FF of
    LANG_GERMAN: Result:='de';
    LANG_FRENCH: Result:='fr';
    LANG_GREEK: Result:='el';
    LANG_LITHUANIAN: Result:='lt';
    LANG_NORWEGIAN: Result:='no';
    LANG_POLISH: Result:='pl';
    LANG_PORTUGUESE: Result:='pt';
    LANG_RUSSIAN: Result:='ru';
    LANG_SPANISH: Result:='es';
    LANG_SWEDISH: Result:='sv';
    LANG_TURKISH: Result:='tr';
    LANG_FINNISH: Result:='fi';
    LANG_DUTCH: Result:='nl';
    LANG_ITALIAN: Result:='it';
    LANG_DANISH: Result:='da';
    LANG_CHINESE: Result:='zh';
    else Result:='en';
  end;
end;

function TLang.IsLanguageAvailable(LangCode: string): Boolean;
begin
  Result := FileExists(GetLangFileName(LangCode));
end;

procedure TLang.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opInsert then
    Translate(AComponent);
end;

procedure TLang.ReadyForTranslateEvent(Sender: TObject);
begin
  Translate(TComponent(Sender));
  (TComponent(Sender) as ITranslate).OnReadyForTranslate(nil);
end;

{**
 * Liest eine Sprache ein
 *}
procedure TLang.SetLangCode(NewLangCode: string);
var
  SectionList: TStringList;
  LangItem: string;
  LangVarPCRE: TPerlRegEx;
  INI: TMemIniFile;
  cc: Integer;

  procedure Prepare(List: TStringList);
  var
    cc: Integer;
  begin
    for cc := 0 to List.Count - 1 do
    begin
      LangItem := List[cc];
      {**
       * Die Stringfolge '\n' durch echten Umbruch ersetzen
       *}
      LangItem := StringReplace(LangItem, '\n', sLineBreak, [rfReplaceAll]);
      {**
       * Sprachkonstanten ersetzen
       *
       * Wenn in einem String ein Wort von Dollarzeichen umschlossen wird, so wird davon
       * ausgegangen, dass es sich um eine Sprachkonstante handelt.
       *
       * Beispiel:
       * [Consts]
       * TODAY=Heute
       * DAY=Tag
       *
       * [Strings]
       * 0=$TODAY$ ist ein guter $DAY$
       *
       * Nach dem Durchlauf hat Self.Strings[0] den Wert:
       * 'Heute ist ein guter Tag'
       *}
      if Pos('$', LangItem) > 0 then
      begin
          if LangVarPCRE.Match(LangItem) then
            repeat
              LangItem := StringReplace(LangItem, LangVarPCRE.Groups[0], Consts[LangVarPCRE.Groups[1]],
                [rfReplaceAll]);
            until not LangVarPCRE.MatchAgain;
      end;
      {**
       * Schlussendlich wird der präparierte String wieder zugewiesen
       *}
      List[cc] := LangItem;
    end;
  end;

  {**
   * Räumt eine Liste auf, indem es alle leeren Strings entfernt
   *}
  procedure CleanList(List: TStringList);
  var
    cc: Integer;
  begin
    for cc := List.Count - 1 downto 0 do
      if Trim(List[cc]) = '' then
        List.Delete(cc);
  end;

  procedure ReadKeyCaptionConsts;
  const
    KeyCapIdents: array[TMenuKeyCap] of string = (
      'KeyBackspaceShort',
      'KeyTabShort',
      'KeyEscapeShort',
      'KeyEnterShort',
      'KeySpaceShort',
      'KeyPageUpShort',
      'KeyPageDownShort',
      'KeyEndShort',
      'KeyHomeShort',
      'KeyArrowLeftShort',
      'KeyArrowUpShort',
      'KeyArrowRightShort',
      'KeyArrowDownShort',
      'KeyInsertShort',
      'KeyDeleteShort',
      'KeyShiftShort',
      'KeyControlShort',
      'KeyAlternateShort');
  var
    cc: Integer;
  begin
    for cc := 0 to Ord(High(TMenuKeyCap)) do
      FMenuKeyCaps[TMenuKeyCap(cc)] := Consts[KeyCapIdents[TMenuKeyCap(cc)]];
  end;

  procedure HookConsts;
  type
    TConstAssign = record
      Name: string;
      Target: PResStringRec;
    end;
  const
    ConstMax = 17;
    ConstResourcesMap: array[0..ConstMax] of TConstAssign = (
      (Name: 'SMsgDlgWarning'; Target: @SMsgDlgWarning),
      (Name: 'SMsgDlgError'; Target: @SMsgDlgError),
      (Name: 'SMsgDlgInformation'; Target: @SMsgDlgInformation),
      (Name: 'SMsgDlgConfirm'; Target: @SMsgDlgConfirm),
      (Name: 'SMsgDlgYes'; Target: @SMsgDlgYes),
      (Name: 'SMsgDlgNo'; Target: @SMsgDlgNo),
      (Name: 'SMsgDlgOK'; Target: @SMsgDlgOK),
      (Name: 'SMsgDlgCancel'; Target: @SMsgDlgCancel),
      (Name: 'SMsgDlgHelp'; Target: @SMsgDlgHelp),
      (Name: 'SMsgDlgHelpNone'; Target: @SMsgDlgHelpNone),
      (Name: 'SMsgDlgHelpHelp'; Target: @SMsgDlgHelpHelp),
      (Name: 'SMsgDlgAbort'; Target: @SMsgDlgAbort),
      (Name: 'SMsgDlgRetry'; Target: @SMsgDlgRetry),
      (Name: 'SMsgDlgIgnore'; Target: @SMsgDlgIgnore),
      (Name: 'SMsgDlgAll'; Target: @SMsgDlgAll),
      (Name: 'SMsgDlgNoToAll'; Target: @SMsgDlgNoToAll),
      (Name: 'SMsgDlgYesToAll'; Target: @SMsgDlgYesToAll),
      (Name: 'SMsgDlgClose'; Target: @SMsgDlgClose)
    );
  var
    cc: Integer;
  begin
    SetLength(FConstResources, ConstMax + 1);
    for cc := 0 to ConstMax do
    begin
      FConstResources[cc] := Consts[ConstResourcesMap[cc].Name];
      HookResourceString(ConstResourcesMap[cc].Target, PChar(FConstResources[cc]));
    end;
  end;

begin
  if (FLangCode = NewLangCode) or not IsLanguageAvailable(NewLangCode) then
    Exit;

  FLangCode := NewLangCode;

  FStrings.Clear;
  FMessages.Clear;
  SectionList := TStringList.Create;
  INI := TMemIniFile.Create(GetLangFileName(LangCode), TEncoding.UTF8);
  LangVarPCRE := TPerlRegEx.Create;
  try
    FLangInternationalName := INI.ReadString(InfoSection, 'InternationalName', '');
    FLangLocalName := INI.ReadString(InfoSection, 'LocalName', LangCode);
    {**
     * Regulären Ausdruck für das Ersetzen von Sprachvariablen initiieren
     *}
    with LangVarPCRE do
    begin
      Options := [preCaseLess, preExtended];
      Compile('\$([\w\d\-]+)\$');
    end;
    {**
     * Read constants
     *}
    INI.ReadSectionValues(ConstsSection, FConsts);
    {**
     * Read strings
     *}
    INI.ReadSection(StringsSection, SectionList);
    CleanList(SectionList);
    for cc := 0 to SectionList.Count - 1 do
      FStrings.Insert(StrToInt(SectionList[cc]), INI.ReadString(StringsSection,
        SectionList[cc], ''));
    {**
     * Read messages
     *}
    SectionList.Clear;
    INI.ReadSection(MessagesSection, SectionList);
    CleanList(SectionList);
    FMessagesOffset := StrToInt(SectionList[0]);
    for cc := 0 to SectionList.Count - 1 do
      FMessages.Insert(StrToInt(SectionList[cc]) - FMessagesOffset,
        INI.ReadString(MessagesSection, SectionList[cc], ''));
    {**
     * Replace used constants in strings and messages
     *}
    Prepare(FStrings);
    Prepare(FMessages);
    {**
     * Static binding of some lang constants
     *}
    ReadKeyCaptionConsts;
    HookConsts;

    FInitialized := True;
    TranslateApplication;
  finally
    INI.Free;
    SectionList.Free;
    LangVarPCRE.Free;
  end;
end;

function TLang.ShortCutToText(ShortCut: TShortCut): string;
var
  Name: string;
  Key: Byte;

  function GetSpecialName(ShortCut: TShortCut): string;
  var
    ScanCode: Integer;
    KeyName: array[0..255] of Char;
  begin
    Result := '';
    ScanCode := MapVirtualKey(LoByte(Word(ShortCut)), 0) shl 16;
    if ScanCode <> 0 then
    begin
      GetKeyNameText(ScanCode, KeyName, Length(KeyName));
      GetSpecialName:=KeyName;
    end;
  end;
begin
  Key := LoByte(Word(ShortCut));
  case Key of
    $08, $09:
      Name := FMenuKeyCaps[TMenuKeyCap(Ord(mkcBkSp) + Key - $08)];
    $0D:
      Name := FMenuKeyCaps[mkcEnter];
    $1B:
      Name := FMenuKeyCaps[mkcEsc];
    $20..$28:
      Name := FMenuKeyCaps[TMenuKeyCap(Ord(mkcSpace) + Key - $20)];
    $2D..$2E:
      Name := FMenuKeyCaps[TMenuKeyCap(Ord(mkcIns) + Key - $2D)];
    $30..$39:
      Name := Chr(Key - $30 + Ord('0'));
    $41..$5A:
      Name := Chr(Key - $41 + Ord('A'));
    $60..$69:
      Name := Chr(Key - $60 + Ord('0'));
    $70..$87:
      Name := 'F' + IntToStr(Key - $6F);
    else
      Name := GetSpecialName(ShortCut);
  end;
  if Name <> '' then
  begin
    Result := '';
    if ShortCut and scCtrl <> 0 then
      Result := Result + FMenuKeyCaps[mkcCtrl] + '+';
    if ShortCut and scAlt <> 0 then
      Result := Result + FMenuKeyCaps[mkcAlt] + '+';
    if ShortCut and scShift <> 0 then
      Result := Result + FMenuKeyCaps[mkcShift] + '+';
    Result := Result + Name;
  end
  else
    Result := '';
end;

{**
 * Übersetzt rekursiv alle Unterobjekte von ComponentHolder
 *}
procedure TLang.Translate(ComponentHolder: TComponent);
var
  Current: TComponent;

  procedure TranslateHint(Hint: string);
  begin
    if Current is TControl then
      TControl(Current).Hint := Hint
    else if Current is TAction then
      TAction(Current).Hint := Hint;
  end;

  procedure TranslateCaption(Caption: string);
  begin
    if Current is TButton then
      TButton(Current).Caption := Caption
    else if Current is TRadioButton then
      TRadioButton(Current).Caption := Caption
    else if Current is TGroupBox then
      TGroupBox(Current).Caption := Caption
    else if Current is TPanel then
      TPanel(Current).Caption := Caption
    else if Current is TCheckBox then
      TCheckBox(Current).Caption := Caption
    else if Current is TTabSheet then
      TTabSheet(Current).Caption := Caption
    else if Current is TLabel then
      TLabel(Current).Caption := Caption
    else if Current is TMenuItem then
      TMenuItem(Current).Caption := Caption
    else if Current is TForm then
      TForm(Current).Caption := Caption
    else if Current is TAction then
      TAction(Current).Caption := Caption
    else if Current is TCustomLinkLabel then
      TLinkLabel(Current).Caption := Caption;
  end;

  procedure TranslateTextHint(TextHint: string);
  begin
    if Current is TCustomEdit then
      TCustomEdit(Current).TextHint := TextHint;
  end;

  {**
   * Übersetzt die aktuelle Komponente in Current nach einem Schema
   *
   * Ein Schema kann mehrere Eigenschaften in einem String für die Übersetzung definieren.
   *
   * Beispiel: '"Caption=13..." "Hint=14"'
   *}
  procedure TranslateSchema(Schema: string);
  var
    SchemaList: TStringList;
    Replacement: string;
    cc: Integer;
  begin
    SchemaList := TStringList.Create;
    try
      SchemaList.CommaText := Schema;
      for cc := 0 to SchemaList.Count - 1 do
      begin
        Schema := LowerCase(SchemaList.Names[cc]);
        Replacement := Translate(SchemaList.ValueFromIndex[cc]);

        if Schema = 'caption' then
          TranslateCaption(Replacement)
        else if Schema = 'hint' then
          TranslateHint(Replacement)
        else if Schema = 'texthint' then
          TranslateTextHint(Replacement);
      end;
    finally
      SchemaList.Free;
    end;
  end;

  {**
   * Liefert die Referenz, vom Objekt welches die ITranslate-Schnittstelle implementiert, falls...
   *
   * - sie tatsächlich die Schnittstelle implementiert
   * - falls ITranslate.IsReadyFroTranslate TRUE liefert
   *
   * gleichzeitig setzt es das OnReadyForTranslate-Event, wenn ITranslate.IsReadyFroTranslate
   * FALSE liefert.
   *
   * Sonst wird nil geliefert.
   *}
  function GetTranslateObject(Component: TComponent): ITranslate;
  begin
    Result := nil;
    if not Supports(Component, ITranslate) then
      Exit;
    Result := Component as ITranslate;
    if not Result.IsReadyForTranslate then
    begin
      Result.OnReadyForTranslate(ReadyForTranslateEvent);
      Result := nil;
    end;
  end;

  procedure TranslateComponent(Component: TComponent);
  var
    TranslateObject: ITranslate;
  begin
    if (Component is TControl) and (TControl(Component).HelpKeyword <> '') then
    begin
      Current := Component;
      TranslateSchema(TControl(Current).HelpKeyword);
    end
    else if (Component is TAction) and (TAction(Component).HelpKeyword <> '') then
    begin
      Current := Component;
      TranslateSchema(TAction(Current).HelpKeyword);
    end;

    TranslateObject:=GetTranslateObject(Component);
    if Assigned(TranslateObject) then
      TranslateObject.Translate;
  end;

  {**
   * Durchläuft alle mit Parent verbundenen Komponenten rekursiv.
   *}
  procedure DeepScan(Parent: TComponent);
  var
    cc: Integer;
  begin
    if Parent is TCustomActionList then
    begin
      with TCustomActionList(Parent) do
        for cc := 0 to ActionCount - 1 do
          TranslateComponent(Actions[cc]);
    end;

    for cc := 0 to Parent.ComponentCount - 1 do
    begin
      TranslateComponent(Parent.Components[cc]);
      if Parent.Components[cc].ComponentCount > 0 then
        DeepScan(Parent.Components[cc]);
    end;
  end;

begin
  {**
   * Das hier bedeutet, dass das Objekt noch nicht bereit für die Übersetzung ist, wenn das
   * der Fall ist...so wird die Prozedur verlassen...doch in GetTranslateObject() wird der
   * Event-Handler für OnReadyForTranslate gesetzt, sodass per Konzeption diese Methode wieder
   * aufgerufen wird, sobald es für die Übersetzung bereit ist.
   *}
  if Supports(ComponentHolder, ITranslate) and (GetTranslateObject(ComponentHolder) = nil) then
    Exit;

  if not FInitialized then
    Exit;

  TranslateComponent(ComponentHolder);
  DeepScan(ComponentHolder);
end;

{**
 * Übersetzt einen beliebigen String
 *
 * Alle Zahlen die im String vorkommen, werden durch den entsprechden String übersetzt.
 *
 * Beispiele:
 * '23...' --> 'Einstellungen...'
 * '22 23' --> 'Klicken Sie auf Einstellungen'
 *
 * Soll eine Zahl nicht übersetzt werden, so ist dieser ein Backslash '\' voranzustellen.
 *
 * Beispiel:
 * '22 23 - \1. 24' --> 'Klicken Sie auf Einstellungen - 1. Eintrag'
 *}
function TLang.Translate(Incoming: string): string;
var
  Index, Offset: Integer;

  function ReplaceCapture(Incoming, Replace: string; GroupOffset, GroupLength: Integer): string;
  var
    FirstPos, LastPos: Integer;
  begin
    FirstPos := GroupOffset;
    LastPos := FirstPos + GroupLength;
    Result := Copy(Incoming, 1, FirstPos - 1) + Replace + Copy(Incoming, LastPos + 1);
    Offset := FirstPos + Length(Replace);
  end;

begin
  {**
   * Die schnellste Variante: Überprüfen, ob der String nicht aus nur einer Zahl besteht.
   *}
  if TryStrToInt(Trim(Incoming), Index) then
  begin
    Result := GetString(Index);
    Exit;
  end;
  {**
   * Die langsamere Variante: Der String wird nach allen vorkommenden Zahlen durchsucht.
   *}
  if FNumberPCRE.Match(Incoming) then
  begin
    Result := Incoming;
    Offset := 1;
    repeat
      Index := FNumberPCRE.NamedGroup('Number');
      if Index >= 0 then
      begin
        Result := ReplaceCapture(Result, GetString(StrToInt(FNumberPCRE.Groups[Index])),
          FNumberPCRE.GroupOffsets[Index], FNumberPCRE.GroupLengths[Index]);
        Continue;
      end;

      Index := FNumberPCRE.NamedGroup('Escaped');
      if Index >= 0 then
      begin
        Result := ReplaceCapture(Result, FNumberPCRE.Groups[Index],
          FNumberPCRE.GroupOffsets[Index], FNumberPCRE.GroupLengths[Index]);
      end;
    until not FNumberPCRE.Match(Result, Offset);
  end;
end;

{**
 * Übersetzt die gesamte Anwendung
 *
 * Erreicht werden sämtliche Komponenten, die über den Owner-Mechanismus von TComponent mit der
 * Application (egal auf welcher Ebene) verbunden sind.
 *
 * Diese Methode wird auch beim setzen der LangCode-Eigenschaft aufgerufen.
 *}
procedure TLang.TranslateApplication;
begin
  Translate(Application);
end;

function ShortCutToTextController(ShortCut: TShortCut): string;
begin
  if Assigned(Lang) then
    Result := Lang.ShortCutToText(ShortCut)
  else
    Result := '';
end;

{** TNameHashedStringList **}

destructor TNameHashedStringList.Destroy;
begin
  FNameHash.Free;

  inherited Destroy;
end;

procedure TNameHashedStringList.Changed;
begin
  inherited Changed;

  FNameHashValid:=False;
end;

function TNameHashedStringList.IndexOfName(const Name: string): Integer;
begin
  UpdateNameHash;
  if CaseSensitive then
    Result := FNameHash.ValueOf(Name)
  else
    Result := FNameHash.ValueOf(UpperCase(Name));
end;

procedure TNameHashedStringList.UpdateNameHash;
var
  cc: Integer;
  Key: string;
  ToUpperCase: Boolean;
begin
  if FNameHashValid then
    Exit;

  if Assigned(FNameHash) then
    FNameHash.Clear
  else
    FNameHash:=TStringHash.Create;

  ToUpperCase:=not CaseSensitive;

  for cc := 0 to Count - 1 do
  begin
    Key := Names[cc];
    if Key <> '' then
    begin
      if ToUpperCase then
        Key := UpperCase(Key);
      FNameHash.Add(Key, cc);
    end;
  end;

  FNameHashValid := True;
end;

initialization

Lang:=nil;

OverwriteProcedure(@ShortCutToText, @ShortCutToTextController, @OriginShortCutToText);

finalization

FreeAndNil(Lang);
RestoreProcedure(@ShortCutToText, OriginShortCutToText);

end.
