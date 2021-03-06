{%MainUnit win32wsstdctrls.pp}
{$IFDEF MEMOHEADER}
type

{ TWin32MemoStrings }

  TWin32MemoStrings = class(TStrings)
  private
    FHandle: HWND;
    FOwner: TWinControl;
    function GetLineLength(Index: Integer): Integer;
    function GetLineStart(Index: Integer): Integer;
  protected
    function GetTextStr: string; override;
    function GetRealCount: integer;
    function GetCount: integer; override;
    function Get(Index : Integer) : string; override;
    //procedure SetSorted(Val : boolean); virtual;
    procedure SetUpdateState(Updating: Boolean); override;
  public
    constructor Create(Handle: HWND; TheOwner: TWinControl);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AddStrings(TheStrings: TStrings); override;
    procedure Clear; override;
    procedure Delete(Index : integer); override;
    procedure Insert(Index : integer; const S: string); override;
    procedure SetTextStr(const Value: string); override;
    //procedure Sort; virtual;
  public
    //property Sorted: boolean read FSorted write SetSorted;
    property Owner: TWinControl read FOwner;
  end;

{$ELSE} // Implementation

function TWin32MemoStrings.GetLineLength(Index: Integer): Integer;
begin
  //{$ifdef WindowsUnicodeSupport}{$else}{$endif WindowsUnicodeSupport}
  {$ifdef WindowsUnicodeSupport}
  if UnicodeEnabledOS then
   Result := SendMessageW(FHandle, EM_LINELENGTH, SendMessageW(FHandle, EM_LINEINDEX, Index, 0), 0)
  else
    Result := SendMessage(FHandle, EM_LINELENGTH, SendMessage(FHandle, EM_LINEINDEX, Index, 0), 0);
  {$else}
  Result := SendMessage(FHandle, EM_LINELENGTH, SendMessage(FHandle, EM_LINEINDEX, Index, 0), 0);
  {$endif WindowsUnicodeSupport}
end;

function TWin32MemoStrings.GetLineStart(Index: Integer): Integer;
begin
  {$ifdef WindowsUnicodeSupport}
  if UnicodeEnabledOS then
    Result := SendMessageW(FHandle, EM_LINEINDEX, Index, 0)
  else
    Result := SendMessage(FHandle, EM_LINEINDEX, Index, 0);
  {$else}
  Result := SendMessage(FHandle, EM_LINEINDEX, Index, 0);
  {$endif WindowsUnicodeSupport}
end;

function TWin32MemoStrings.GetTextStr: string;
begin
  Result := win32proc.GetControlText(FHandle);
end;

function TWin32MemoStrings.GetRealCount: integer;
begin
  Result := SendMessage(FHandle, EM_GETLINECOUNT, 0, 0);
end;

function TWin32MemoStrings.GetCount: integer;
begin
  Result := GetRealCount;
  if Get(Result-1) = '' then Dec(Result);
end;

function TWin32MemoStrings.Get(Index: Integer): string;
var
  len: Integer;
{$ifdef WindowsUnicodeSupport}
  WideBuffer: WideString;
  AnsiBuffer: string;
{$endif WindowsUnicodeSupport}
begin
  len := GetLineLength(Index);
  if len=0 then
  begin
    Result := '';
    exit;
  end;
{$ifdef WindowsUnicodeSupport}
  if UnicodeEnabledOS then
  begin
    Setlength(WideBuffer, len);
    PWord(@WideBuffer[1])^ := len+1;
    len := SendMessageW(FHandle, EM_GETLINE, Index, lparam(PWideChar(WideBuffer)));

    Result := UTF16ToUTF8(WideBuffer);
  end
  else
  begin
    Setlength(AnsiBuffer, len);
    PWord(@AnsiBuffer[1])^ := len+1;
    len := SendMessage(FHandle, EM_GETLINE, Index, lparam(PChar(AnsiBuffer)));

    Result := AnsiToUtf8(AnsiBuffer);
  end;
{$else}
  Setlength(Result, len);

  // no need for temp buf and moving
  // the result is without null terminator.
  PWord(@Result[1])^ := len+1;
  len := SendMessage(FHandle, EM_GETLINE, Index, lparam(pchar(Result)));

  // read just length in case something went wrong
  Setlength(Result, len);
{$endif}
end;

procedure TWin32MemoStrings.SetUpdateState(Updating: Boolean);
begin
  Windows.SendMessage(FHandle, WM_SETREDRAW, WPARAM(not Updating), 0);
  if not Updating then
    Windows.InvalidateRect(FHandle, nil, TRUE);
end;

constructor TWin32MemoStrings.Create(Handle: HWND; TheOwner: TWinControl);
begin
  inherited Create;
  FHandle := Handle;
  FOwner := TheOwner;
end;

destructor TWin32MemoStrings.Destroy;
begin
  // do nothing
  inherited Destroy;
end;

procedure TWin32MemoStrings.Assign(Source: TPersistent);
var
  S: TStrings absolute Source;
begin
  if Source is TStrings then
  begin
    // to prevent Clear and then SetText we need to use our own Assign
    TextLineBreakStyle := S.TextLineBreakStyle; //put this first to call CheckSpecialChars if not done yet
    QuoteChar := S.QuoteChar;
    Delimiter := S.Delimiter;
    NameValueSeparator := S.NameValueSeparator;
    Text := S.Text;
  end
  else
    inherited Assign(Source);
end;

procedure TWin32MemoStrings.AddStrings(TheStrings: TStrings);
begin
  SetTextStr(GetTextStr + TStrings(TheStrings).Text);
end;

procedure TWin32MemoStrings.Clear;
begin
  SetText('');
end;

procedure TWin32MemoStrings.Delete(Index: integer);
var
  LineStart,
  LineEnd: Integer;
begin
  LineStart := GetLineStart(Index);
  LineEnd := GetLineStart(Index+1);
  if LineEnd < 0 then LineEnd := LineStart+GetLineLength(Index);
  {$ifdef WindowsUnicodeSupport}
  if UnicodeEnabledOS then
  begin
    SendMessageW(FHandle, EM_SETSEL, LineStart, LineEnd);
    SendMessageW(FHandle, EM_REPLACESEL,0 , lparam(PWChar('')));
  end
  else
  begin
    SendMessage(FHandle, EM_SETSEL, LineStart, LineEnd);
    SendMessage(FHandle, EM_REPLACESEL,0 , lparam(PChar('')));
  end;
  {$else}
  SendMessage(FHandle, EM_SETSEL, LineStart, LineEnd);
  SendMessage(FHandle, EM_REPLACESEL,0 , lparam(PChar('')));
  {$endif WindowsUnicodeSupport}
end;

procedure TWin32MemoStrings.Insert(Index: integer; const S: string);
var
  LineStart: Integer;
  NewLine: String;
begin
  LineStart := GetLineStart(Index);
  if Index < GetRealCount then
  begin
    //insert with LineEnding
    LineStart := GetLineStart(Index);
    NewLine := S+LineEnding;
   {$ifdef WindowsUnicodeSupport}
    if UnicodeEnabledOS
    then
    begin
      SendMessageW(FHandle, EM_SETSEL, LineStart, LineStart);
      SendMessageW(FHandle, EM_REPLACESEL, 0, lparam(PWideChar(UTF8ToUTF16(NewLine))))
    end
    else
    begin
      SendMessage(FHandle, EM_SETSEL, LineStart, LineStart);
      SendMessage(FHandle, EM_REPLACESEL, 0, lparam(Utf8ToAnsi(NewLine)))
    end;
   {$else}
    SendMessage(FHandle, EM_SETSEL, LineStart, LineStart);
    SendMessage(FHandle, EM_REPLACESEL, 0, lparam(PChar(NewLine)));
   {$endif WindowsUnicodeSupport}
  end
  else
  begin
    //append with a preceding LineEnding
    LineStart := GetLineStart(Index-1)+GetLineLength(Index-1);
    {$ifdef WindowsUnicodeSupport}
    if UnicodeEnabledOS then
      SendMessageW(FHandle, EM_SETSEL, LineStart, LineStart)
    else
      SendMessage(FHandle, EM_SETSEL, LineStart, LineStart);
    {$else}
    SendMessage(FHandle, EM_SETSEL, LineStart, LineStart);
    {$endif WindowsUnicodeSupport}
    if GetRealCount = Count then
      NewLine := LineEnding+S+LineEnding
    else
      NewLine := S+LineEnding;
   {$ifdef WindowsUnicodeSupport}
    if UnicodeEnabledOS
    then
      SendMessageW(FHandle, EM_REPLACESEL, 0, lparam(PWideChar(UTF8ToUTF16(NewLine))))
    else
      SendMessage(FHandle, EM_REPLACESEL, 0, lparam(Utf8ToAnsi(NewLine)));
   {$else}
    SendMessage(FHandle, EM_REPLACESEL, 0, lparam(PChar(NewLine)));
   {$endif}
  end;
end;

procedure TWin32MemoStrings.SetTextStr(const Value: string);
var
  Msg: TLMessage;
  AdjustedValue: String;
begin
  AdjustedValue := AdjustLineBreaks(Value);
  if (AdjustedValue <> Text) then
  begin
  {$ifdef WindowsUnicodeSupport}
    if UnicodeEnabledOS
    then Windows.SetWindowTextW(FHandle, PWideChar(UTF8ToUTF16(AdjustedValue)))
    else Windows.SetWindowText(FHandle, PChar(Utf8ToAnsi(AdjustedValue)));
  {$else}
    SendMessage(FHandle, WM_SETTEXT, 0, LPARAM(PChar(AdjustedValue)));
  {$endif}
    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Msg := CM_TEXTCHANGED;
    DeliverMessage(Owner, Msg);
  end;
end;

{$ENDIF}
