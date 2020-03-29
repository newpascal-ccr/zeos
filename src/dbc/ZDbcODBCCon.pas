{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           ODBC Database Connectivity Classes           }
{                                                         }
{            Originally written by EgonHugeist            }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcODBCCon;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_ODBC} //if set we have an empty unit
uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZDbcIntfs, ZDbcConnection, ZTokenizer, ZGenericSqlAnalyser, ZDbcLogging,
  ZURL, ZCompatibility, ZPlainODBCDriver, ZClasses;


type
  {** Implements OleDB Database Driver. }
  TZODBCDriver = class(TZAbstractDriver)
  public
    constructor Create; override;
    function Connect(const Url: TZURL): IZConnection; override;
    function GetTokenizer: IZTokenizer; override;
  end;

  IZODBCConnection = Interface(IZConnection)
    ['{D149ABA3-AD8B-404F-A804-77608C596394}']
    procedure CheckDbcError(RETCODE: SQLRETURN);
    function GetArrayRowSupported: Boolean;
    function GetArraySelectSupported: Boolean;
    function GetPlainDriver: TZODBC3PlainDriver;
    procedure SetLastWarning(Warning: EZSQLWarning);
    function ODBCVersion: SQLUSMALLINT;
  End;

  TZAbstractODBCConnection = class(TZAbstractDbcConnection,
    IZTransaction)
  private
    fPlainDriver: TZODBC3PlainDriver;
    fHDBC: SQLHDBC;
    fHENV: SQLHENV;
    fRetaining: Boolean;
    fLastWarning: EZSQLWarning;
    fCatalog: String; //cached
    fODBCVersion: SQLUSMALLINT;
    fArraySelectSupported, fArrayRowSupported: Boolean;
    fServerProvider: TZServerProvider;
    FSavePoints: TStrings;
    FRestartTransaction: Boolean;
    FWeakODBCConRefOfSelf: Pointer;
    procedure DetermineAttachmentCharset;
  protected
    procedure InternalCreate; override;
    procedure InternalClose; override;
    function SavePoint(const AName: String): Integer; virtual; abstract;
    procedure ReleaseSavePoint(Index: Integer); virtual; abstract;
    procedure RollBackTo(Index: Integer); virtual; abstract;
  public
    function GetArrayRowSupported: Boolean;
    function GetArraySelectSupported: Boolean;
    function GetPlainDriver: TZODBC3PlainDriver;
    procedure CheckDbcError(RETCODE: SQLRETURN);
    procedure SetLastWarning(Warning: EZSQLWarning);
    function ODBCVersion: Word;
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;

    function GetBinaryEscapeString(const Value: TBytes): String; overload; override;
    function GetBinaryEscapeString(const Value: RawByteString): String; overload; override;

    procedure SetReadOnly(Value: Boolean); override;
    function GetCatalog: string; override;
    procedure SetCatalog(const Catalog: string); override;

    procedure Commit;
    procedure Rollback;
    procedure SetAutoCommit(Value: Boolean); override;
    procedure SetTransactionIsolation(Level: TZTransactIsolationLevel); override;
    function StartTransaction: Integer;

    procedure Open; override;

    function GetWarnings: EZSQLWarning; override;
    procedure ClearWarnings; override;
    function GetServerProvider: TZServerProvider; override;
  end;

  TZODBCConnectionW = class(TZAbstractODBCConnection, IZODBCConnection, IZConnection)
  protected
    procedure ExecuteImmediat(const SQL: UnicodeString; LoggingCategory: TZLoggingCategory); override;
    function SavePoint(const AName: String): Integer; override;
    procedure ReleaseSavePoint(Index: Integer); override;
    procedure RollBackTo(Index: Integer); override;
  public
    function CreateStatementWithParams(Info: TStrings): IZStatement;
    function PrepareCallWithParams(const Name: String; Info: TStrings):
      IZCallableStatement;
    function PrepareStatementWithParams(const SQL: string; Info: TStrings):
      IZPreparedStatement;

    function NativeSQL(const SQL: string): string; override;
    function GetCatalog: string; override;
    procedure SetCatalog(const Catalog: string); override;
  end;

  TZODBCConnectionA = class(TZAbstractODBCConnection, IZODBCConnection, IZConnection)
  protected
    procedure ExecuteImmediat(const SQL: RawByteString; LoggingCategory: TZLoggingCategory); override;
    function SavePoint(const AName: String): Integer; override;
    procedure ReleaseSavePoint(Index: Integer); override;
    procedure RollBackTo(Index: Integer); override;
  public
    function CreateStatementWithParams(Info: TStrings): IZStatement;
    function PrepareCallWithParams(const Name: String; Info: TStrings):
      IZCallableStatement;
    function PrepareStatementWithParams(const SQL: string; Info: TStrings):
      IZPreparedStatement;

    function NativeSQL(const SQL: string): string; override;
    function GetCatalog: string; override;
    procedure SetCatalog(const Catalog: string); override;
  end;

  TIZBlobDynArray = array of IZBlob;
  TIZBlobsDynArray = array of TIZBlobDynArray;

{$ENDIF ZEOS_DISABLE_ODBC} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_ODBC} //if set we have an empty unit

uses
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  ZODBCToken, ZDbcODBCUtils, ZDbcODBCMetadata, ZDbcODBCStatement, ZDbcUtils,
  ZPlainDriver, ZSysUtils, ZEncoding, ZFastCode, ZDbcProperties,
  ZMessages, ZCollections {$IFDEF NO_INLINE_SIZE_CHECK}, Math{$ENDIF};

{ TZODBCDriver }

{**
  Attempts to make a database connection to the given URL.
  The driver should return "null" if it realizes it is the wrong kind
  of driver to connect to the given URL.  This will be common, as when
  the JDBC driver manager is asked to connect to a given URL it passes
  the URL to each loaded driver in turn.

  <P>The driver should raise a SQLException if it is the right
  driver to connect to the given URL, but has trouble connecting to
  the database.

  <P>The java.util.Properties argument can be used to passed arbitrary
  string tag/value pairs as connection arguments.
  Normally at least "user" and "password" properties should be
  included in the Properties.

  @param url the TZURL of the database to which to connect
  @return a <code>Connection</code> object that represents a
    connection to the URL
}
function TZODBCDriver.Connect(const Url: TZURL): IZConnection;
begin
  if Url.Protocol = 'odbc_w' then
    Result := TZODBCConnectionW.Create(URL)
  else
    Result := TZODBCConnectionA.Create(URL)
end;

{**
  Constructs this object with default properties.
}
constructor TZODBCDriver.Create;
begin
  inherited Create;
  AddSupportedProtocol(AddPlainDriverToCache(TODBC3UnicodePlainDriver.Create));
  AddSupportedProtocol(AddPlainDriverToCache(TODBC3RawPlainDriver.Create));
end;

{**
  Creates a ODBC tokenizer object.
  @returns a created tokenizer object.
}
function TZODBCDriver.GetTokenizer: IZTokenizer;
begin
  Result := TZODBCTokenizer.Create;
end;

{ TZAbstractODBCConnection }

procedure TZAbstractODBCConnection.AfterConstruction;
var ODBCConnection: IZODBCConnection;
begin
  QueryInterface(IZODBCConnection, ODBCConnection);
  FWeakODBCConRefOfSelf := Pointer(ODBCConnection);
  ODBCConnection :=  nil;
  inherited AfterConstruction; //dec constructors RefCnt
end;

procedure TZAbstractODBCConnection.CheckDbcError(RETCODE: SQLRETURN);
begin
  if RetCode <> SQL_SUCCESS then
    CheckODBCError(RetCode, fHDBC, SQL_HANDLE_DBC, '', self, IZODBCConnection(FWeakODBCConRefOfSelf));
end;

{**
  Clears all warnings reported for this <code>Connection</code> object.
  After a call to this method, the method <code>getWarnings</code>
    returns null until a new warning is reported for this Connection.
}
procedure TZAbstractODBCConnection.ClearWarnings;
begin
  FreeAndNil(fLastWarning);
end;

{**
  Releases a Connection's database and JDBC resources
  immediately instead of waiting for
  them to be automatically released.

  <P><B>Note:</B> A Connection is automatically closed when it is
  garbage collected. Certain fatal errors also result in a closed
  Connection.
}
procedure TZAbstractODBCConnection.InternalClose;
begin
  if Closed or not Assigned(fPLainDriver) then
    Exit;
  try
    if not AutoCommit then begin
      SetAutoCommit(True); //stop TA
      AutoCommit := False; //remainder for reopen
    end;
  finally
    try
      if fHDBC <> nil then
        CheckDbcError(fPLainDriver.SQLDisconnect(fHDBC));
    finally
      if Assigned(fHDBC) then begin
        fPlainDriver.SQLFreeHandle(SQL_HANDLE_DBC, fHDBC);
        fHDBC := nil;
      end;
    end;
  end;
end;

{**
  Makes all changes made since the previous
  commit/rollback permanent and releases any database locks
  currently held by the Connection. This method should be
  used only when auto-commit mode has been disabled.
  @see #setAutoCommit
}
procedure TZAbstractODBCConnection.Commit;
begin
  if Closed then
    raise EZSQLException.Create(cSConnectionIsNotOpened);
  if AutoCommit then
    raise EZSQLException.Create(SInvalidOpInAutoCommit);
  if FSavePoints.Count > 0
  then ReleaseSavePoint(FSavePoints.Count-1)
  else begin
    CheckDbcError(fPlainDriver.SQLEndTran(SQL_HANDLE_DBC,fHDBC,SQL_COMMIT));
    if not FRestartTransaction then
      SetAutoCommit(True);
  end;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZAbstractODBCConnection.Destroy;
begin
  inherited Destroy;
  if Assigned(fHENV) then
    fPlainDriver.SQLFreeHandle(SQL_HANDLE_ENV, fHENV);
  FSavePoints.Free;
  ClearWarnings;
end;

procedure TZAbstractODBCConnection.DetermineAttachmentCharset;
var
  CodePageName: String;
  IPos, BytesPerChar, CodePage: Integer;
const CPEncodings: array[Boolean] of TZCharEncoding = (ceAnsi, ceUTF8);
label fail;
begin
  if (Info.Values[ConnProps_Codepage] <> '') or (Info.Values[ConnProps_Charset] <> '') then begin
    //set a custom codepage to notify zeos about conversion routines note: cp must be equal for all fields else use the W driver
    //first place in a name
    //second use ':' for the codepage
    //third use '/' for the maximum amount of bytes / character equal to database defined charset
    //example: codepage=latin1:1252/1
    //example: characterset=utf8:65001/4
    CodePageName := Info.Values[ConnProps_Codepage];
    if CodePageName = '' then
      CodePageName := Info.Values[ConnProps_Charset];
    IPos := ZFastCode.Pos('/', CodePageName);
    if IPos > 0 then
      CodePageName[IPos] := #0 else
      goto fail;
    BytesPerChar := ZFastCode.{$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(PChar(@CodePageName[IPos+1]), 1);
    IPos := ZFastCode.Pos(':', CodePageName);
    if IPos > 0 then
      CodePageName[IPos] := #0 else
      goto fail;
    CodePage := ZFastCode.{$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(PChar(@CodePageName[IPos+1]), ZOSCodePage);
    CodePageName := Copy(CodePageName, 1, iPos-1);
    if Supports(fPlainDriver, IODBC3UnicodePlainDriver) then
      fPlainDriver.AddCodePage(CodePageName, 0, ceUTF16, CodePage, '', BytesPerChar)
    else
      fPlainDriver.AddCodePage(CodePageName, 0, CPEncodings[CodePage = 65001], CodePage, '', BytesPerChar);
    CheckCharEncoding(CodePageName);
  end else
fail:
    if Supports(fPlainDriver, IODBC3UnicodePlainDriver)
    then CheckCharEncoding('CP_UTF16')
    else CheckCharEncoding('CP_ACP');
end;

{**
  Returns the BinaryString in a Tokenizer-detectable kind
  If the Tokenizer don't need to pre-detect it Result = BinaryString
  @param Value represents the Byte-Array
  @result the detectable Binary String
}
function TZAbstractODBCConnection.GetBinaryEscapeString(const Value: TBytes): String;
begin
  Result := GetSQLHexString(Pointer(Value), Length(Value), True);
end;

function TZAbstractODBCConnection.GetArrayRowSupported: Boolean;
begin
  Result := fArrayRowSupported;
end;

function TZAbstractODBCConnection.GetArraySelectSupported: Boolean;
begin
  Result := fArraySelectSupported;
end;

{**
  Returns the BinaryString in a Tokenizer-detectable kind
  If the Tokenizer don't need to pre-detect it Result = BinaryString
  @param Value represents the Binary-String
  @result the detectable Binary String
}
function TZAbstractODBCConnection.GetBinaryEscapeString(
  const Value: RawByteString): String;
begin
  Result := GetSQLHexString(Pointer(Value), Length(Value), True);
end;

{**
  Returns the Connection's current catalog name.
  @return the current catalog name or null
}
function TZAbstractODBCConnection.GetCatalog: string;
begin
  Result := fCatalog;
end;

function TZAbstractODBCConnection.GetPlainDriver: TZODBC3PlainDriver;
begin
  Result := fPlainDriver;
end;

function TZAbstractODBCConnection.GetServerProvider: TZServerProvider;
begin
  Result := fServerProvider;
end;

{**
  Returns the first warning reported by calls on this Connection.
  <P><B>Note:</B> Subsequent warnings will be chained to this
  SQLWarning.
  @return the first SQLWarning or null
}
function TZAbstractODBCConnection.GetWarnings: EZSQLWarning;
begin
  Result := fLastWarning;
end;

procedure TZAbstractODBCConnection.InternalCreate;
begin
  FSavePoints := TStringList.Create;
  fPlainDriver := TZODBC3PlainDriver(GetIZPlainDriver.GetInstance);
  fHENV := nil;
  fHDBC := nil;
  if Supports(fPlainDriver, IODBC3UnicodePlainDriver) then
    FMetaData := TODBCDatabaseMetadataW.Create(Self, Url, fHDBC)
  else
    FMetaData := TODBCDatabaseMetadataA.Create(Self, Url, fHDBC);
  fCatalog := '';
  if not SQL_SUCCEDED(fPlainDriver.SQLAllocHandle(SQL_HANDLE_ENV, Pointer(SQL_NULL_HANDLE), fHENV)) then
    raise EZSQLException.Create('Couldn''t allocate an Environment handle');
  //Try to SET Major Version 3 and minior Version 8
  if SQL_SUCCEDED(fPlainDriver.SQLSetEnvAttr(fHENV, SQL_ATTR_ODBC_VERSION, SQL_OV_ODBC3_80, 0)) then
    fODBCVersion := {%H-}Word(SQL_OV_ODBC3_80)
  else begin
    //set minimum Major Version 3
    CheckODBCError(fPlainDriver.SQLSetEnvAttr(fHENV, SQL_ATTR_ODBC_VERSION, SQL_OV_ODBC3, 0),
      fHENV, SQL_HANDLE_ENV, 'SQL_ATTR_ODBC_VERSION', Self, IZODBCConnection(FWeakODBCConRefOfSelf));
    fODBCVersion := {%H-}Word(SQL_OV_ODBC3) * 100;
  end;
end;

function TZAbstractODBCConnection.ODBCVersion: Word;
begin
  Result := fODBCVersion;
end;

{**
  Opens a connection to database server with specified parameters.
}
procedure TZAbstractODBCConnection.Open;
type
  TDriverNameAndServerProvider = record
    DriverName: String;
    Provider: TZServerProvider;
  end;
const
  KnownDriverName2TypeMap: array[0..22] of TDriverNameAndServerProvider = (
    (DriverName: 'SQLNCLI';     Provider: spMSSQL),
    (DriverName: 'SQLSRV';      Provider: spMSSQL),
    (DriverName: 'LIBTDSODBC';  Provider: spMSSQL),
    (DriverName: 'IVSS';        Provider: spMSSQL),
    (DriverName: 'IVMSSS';      Provider: spMSSQL),
    (DriverName: 'PBSS';        Provider: spMSSQL),
    (DriverName: 'DB2CLI';      Provider: spDB2),
    (DriverName: 'LIBDB2';      Provider: spDB2),
    (DriverName: 'IVDB2';       Provider: spDB2),
    (DriverName: 'PBDB2';       Provider: spDB2),
    (DriverName: 'MSDB2';       Provider: spDB2),
    (DriverName: 'CWBODBC';     Provider: spDB2),
    (DriverName: 'MYODBC';      Provider: spMySQL),
    (DriverName: 'SQORA';       Provider: spOracle),
    (DriverName: 'MSORCL';      Provider: spOracle),
    (DriverName: 'PBOR';        Provider: spOracle),
    (DriverName: 'IVOR';        Provider: spOracle),
    (DriverName: 'ODBCFB';      Provider: spIB_FB),
    (DriverName: 'IB';          Provider: spIB_FB),
    (DriverName: 'SQLITE';      Provider: spSQLite),
    (DriverName: 'PSQLODBC';    Provider: spPostgreSQL),
    (DriverName: 'NXODBCDRIVER';Provider: spNexusDB),
    (DriverName: 'ICLIT09B';    Provider: spInformix)
    );
var
  tmp, OutConnectString: String;
  TimeOut: NativeUInt;
  aLen: SQLSMALLINT;
  ConnectStrings: TStrings;
  DriverCompletion: SQLUSMALLINT;
  InfoValue: SQLUINTEGER;
begin
  if not Closed then
    Exit;
  DetermineAttachmentCharset; //do this by default!
  CheckODBCError(fPLainDriver.SQLAllocHandle(SQL_HANDLE_DBC,fHENV,fHDBC),fHENV,
    SQL_HANDLE_ENV, '', Self, IZODBCConnection(FWeakODBCConRefOfSelf));
  if Info.Values[ConnProps_Timeout] <> '' then
  begin
    TimeOut := {$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(Info.Values[ConnProps_Timeout],0);
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_CONNECTION_TIMEOUT, SQLPOINTER(TimeOut), 0));
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_LOGIN_TIMEOUT, SQLPOINTER(TimeOut), SQL_LOGIN_TIMEOUT_DEFAULT));
  end;

  DriverCompletion := SQL_DRIVER_NOPROMPT;
  tmp := Info.Values[ConnProps_DriverCompletion];
  if tmp <> '' then
    if tmp = 'SQL_DRIVER_PROMPT' then
      DriverCompletion := SQL_DRIVER_PROMPT
    else if tmp = 'SQL_DRIVER_COMPLETE' then
      DriverCompletion := SQL_DRIVER_COMPLETE
    else if tmp = 'SQL_DRIVER_COMPLETE_REQUIRED' then
      DriverCompletion := SQL_DRIVER_COMPLETE_REQUIRED;

  ConnectStrings := SplitString(DataBase, ';');
  if StrToBoolEx(ConnectStrings.Values[ConnProps_TrustedConnection]) then
    tmp := DataBase
  else
  begin
    ConnectStrings.Values[ConnProps_UID] := User;
    ConnectStrings.Values[ConnProps_PWD] := PassWord;
    tmp := ComposeString(ConnectStrings, ';');
  end;

  SetLength(OutConnectString, 1024);
  try
    CheckDbcError(fPLainDriver.SQLDriverConnect(fHDBC,
      {$IFDEF MSWINDOWS}SQLHWND(GetDesktopWindow){$ELSE}nil{$ENDIF},
      Pointer(tmp), Length(tmp), Pointer(OutConnectString),
      Length(OutConnectString), @aLen, DriverCompletion));
    SetLength(OutConnectString, aLen);
    CheckDbcError(fPlainDriver.SQLGetInfo(fHDBC, SQL_PARAM_ARRAY_SELECTS, @InfoValue, SizeOf(SQLUINTEGER), nil));
    fArraySelectSupported := InfoValue = SQL_PAS_BATCH;
    CheckDbcError(fPlainDriver.SQLGetInfo(fHDBC, SQL_PARAM_ARRAY_ROW_COUNTS, @InfoValue, SizeOf(SQLUINTEGER), nil));
    fArrayRowSupported := InfoValue = SQL_PARC_BATCH;
  finally
    FreeAndNil(ConnectStrings)
  end;
  inherited Open;
  inherited SetTransactionIsolation(GetMetaData.GetDatabaseInfo.GetDefaultTransactionIsolation);
  inherited SetReadOnly(GetMetaData.GetDatabaseInfo.IsReadOnly);
  if not AutoCommit then begin
    AutoCommit := True;
    SetAutoCommit(False);
  end;
  fRetaining := GetMetaData.GetDatabaseInfo.SupportsOpenCursorsAcrossCommit and
                GetMetaData.GetDatabaseInfo.SupportsOpenCursorsAcrossRollback;
  tmp := UpperCase(GetMetaData.GetDatabaseInfo.GetDriverName);
  fServerProvider := spUnknown;
  for aLen := low(KnownDriverName2TypeMap) to high(KnownDriverName2TypeMap) do
    if StartsWith(tmp, KnownDriverName2TypeMap[aLen].DriverName) then begin
      fServerProvider := KnownDriverName2TypeMap[aLen].Provider;
      Break;
    end;
  if fServerProvider = spMSSQL then begin
    { find out which encoding the raw columns do have }
    with CreateStatement.ExecuteQuery(
      'SELECT DATABASEPROPERTYEX('+QuotedStr(GetCatalog)+', ''Collation'') as DatabaseCollation, '+
      '  COLLATIONPROPERTY(CAST(DATABASEPROPERTYEX('+QuotedStr(GetCatalog)+', ''Collation'') as NVARCHAR(255)), ''Codepage'') as Codepage') do begin
      if Next and not IsNull(FirstDbcIndex) then begin
        ConSettings.ClientCodePage := New(PZCodePage);
        if Supports(fPlainDriver, IODBC3UnicodePlainDriver)
        then ConSettings.ClientCodePage.Encoding := ceUTF16//well a "mixed" encoding i have not prepared yet...
        else ConSettings.ClientCodePage.Encoding := ceAnsi;
        ConSettings.ClientCodePage.IsStringFieldCPConsistent := True;
        ConSettings.ClientCodePage.CP := GetInt(FirstDbcIndex + 1);
        ConSettings.ClientCodePage.Name := GetString(FirstDbcIndex); //@least
        //see Appendix G DBCS/Unicode Mapping Tables
        case ConSettings.ClientCodePage.CP of
          932 {Japanese},
          936 {Simplified Chinese},
          949 {Korean},
          950 {Traditional Chinese}: ConSettings.ClientCodePage.CharWidth := 2;
          else ConSettings.ClientCodePage.CharWidth := 1;
        end;
        FDisposeCodePage := True;
      end;
      Close;
    end;
  end;
end;

{**
  Drops all changes made since the previous
  commit/rollback and releases any database locks currently held
  by this Connection. This method should be used only when auto-
  commit has been disabled.
  @see #setAutoCommit
}
procedure TZAbstractODBCConnection.Rollback;
begin
  if Closed then
    raise EZSQLException.Create(cSConnectionIsNotOpened);
  if AutoCommit then
    raise EZSQLException.Create(SInvalidOpInAutoCommit);
  if FSavePoints.Count > 0
  then RollbackTo(FSavePoints.Count-1)
  else begin
    CheckDbcError(fPlainDriver.SQLEndTran(SQL_HANDLE_DBC,fHDBC,SQL_ROLLBACK));
    if not FRestartTransaction then
      SetAutoCommit(True);
  end;
end;

{**
  Sets this connection's auto-commit mode.
  If a connection is in auto-commit mode, then all its SQL
  statements will be executed and committed as individual
  transactions.  Otherwise, its SQL statements are grouped into
  transactions that are terminated by a call to either
  the method <code>commit</code> or the method <code>rollback</code>.
  By default, new connections are in auto-commit mode.

  The commit occurs when the statement completes or the next
  execute occurs, whichever comes first. In the case of
  statements returning a ResultSet, the statement completes when
  the last row of the ResultSet has been retrieved or the
  ResultSet has been closed. In advanced cases, a single
  statement may return multiple results as well as output
  parameter values. In these cases the commit occurs when all results and
  output parameter values have been retrieved.

  @param autoCommit true enables auto-commit; false disables auto-commit.
}
const CommitMode: Array[Boolean] of Pointer = (SQL_AUTOCOMMIT_OFF, SQL_AUTOCOMMIT_ON);
procedure TZAbstractODBCConnection.SetAutoCommit(Value: Boolean);
begin
  if Value <> AutoCommit then begin
    FRestartTransaction := AutoCommit;
    FSavePoints.Clear;
    if not Closed then
      CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC,SQL_ATTR_AUTOCOMMIT,CommitMode[Value],0));
    AutoCommit := Value;
  end;
end;

procedure TZAbstractODBCConnection.SetCatalog(const Catalog: string);
begin
  fCatalog := Catalog;
end;

procedure TZAbstractODBCConnection.SetLastWarning(Warning: EZSQLWarning);
begin
  ClearWarnings;
  fLastWarning := Warning;
end;

{**
  Puts this connection in read-only mode as a hint to enable
  database optimizations.

  <P><B>Note:</B> This method cannot be called while in the
  middle of a transaction.

  @param readOnly true enables read-only mode; false disables
    read-only mode.
}
const AccessMode: array[Boolean] of Pointer = (SQL_MODE_READ_WRITE, SQL_MODE_READ_ONLY);
procedure TZAbstractODBCConnection.SetReadOnly(Value: Boolean);
begin
  if Value <> ReadOnly then begin
    if not Closed then
      CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC,SQL_ATTR_ACCESS_MODE,AccessMode[Value],0));
    inherited SetReadOnly(Value);
  end;
end;

{**
  Attempts to change the transaction isolation level to the one given.
  The constants defined in the interface <code>Connection</code>
  are the possible transaction isolation levels.

  <P><B>Note:</B> This method cannot be called while
  in the middle of a transaction.

  @param level one of the TRANSACTION_* isolation values with the
    exception of TRANSACTION_NONE; some databases may not support other values
  @see DatabaseMetaData#supportsTransactionIsolationLevel
}
const ODBCTIL: array[TZTransactIsolationLevel] of Pointer =
  ( nil,
    Pointer(SQL_TRANSACTION_READ_UNCOMMITTED),
    Pointer(SQL_TRANSACTION_READ_COMMITTED),
    Pointer(SQL_TRANSACTION_REPEATABLE_READ),
    Pointer(SQL_TRANSACTION_SERIALIZABLE)
  );
procedure TZAbstractODBCConnection.SetTransactionIsolation(
  Level: TZTransactIsolationLevel);
begin
  if (TransactIsolationLevel <> Level) then begin
    if not Closed then
      CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC,SQL_ATTR_TXN_ISOLATION,ODBCTIL[Level],0));
    inherited SetTransactionIsolation(Level);
  end;
end;

function TZAbstractODBCConnection.StartTransaction: Integer;
var S: String;
begin
  if Closed then
    Open;
  if AutoCommit then begin
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC,SQL_ATTR_AUTOCOMMIT,SQL_AUTOCOMMIT_OFF,0));
    AutoCommit := False;
    Result := 1;
  end else begin
    Result := FSavePoints.Count+2;
    S := 'SP'+ZFastCode.IntToStr(NativeUint(Self))+'_'+ZFastCode.IntToStr(Result);
    SavePoint(S);
  end;
end;

{ TZODBCConnectionW }

{**
  Creates a <code>Statement</code> object for sending
  SQL statements to the database.
  SQL statements without parameters are normally
  executed using Statement objects. If the same SQL statement
  is executed many times, it is more efficient to use a
  <code>PreparedStatement</code> object.
  <P>
  Result sets created using the returned <code>Statement</code>
  object will by default have forward-only type and read-only concurrency.

  @param Info a statement parameters.
  @return a new Statement object
}
function TZODBCConnectionW.CreateStatementWithParams(
  Info: TStrings): IZStatement;
begin
  Result := TZODBCStatementW.Create(Self, fHDBC, Info);
end;

procedure TZODBCConnectionW.ExecuteImmediat(const SQL: UnicodeString;
  LoggingCategory: TZLoggingCategory);
var STMT: SQLHSTMT;
begin
  if SQL = '' then
    Exit;
  STMT := nil;
  CheckDbcError(fPlainDriver.SQLAllocHandle(SQL_HANDLE_STMT, fHDBC, STMT));
  try
    CheckDbcError(TODBC3UnicodePlainDriver(fPlainDriver).SQLExecDirectW(STMT,
      Pointer(SQL), Length(SQL)));
  finally
    if STMT <> nil then
      CheckDbcError(fPlainDriver.SQLFreeHandle(SQL_HANDLE_STMT, STMT));
  end;
end;

{**  Returns the Connection's current catalog name.
  @return the current catalog name or null
}
function TZODBCConnectionW.GetCatalog: string;
var
  {$IFNDEF UNICODE}
  Buf: ZWideString;
  {$ENDIF}
  aLen: SQLINTEGER;
begin
  Result := inherited GetCatalog;
  if Result = '' then begin
    CheckDbcError((fPlainDriver as TODBC3UnicodePlainDriver).SQLGetConnectAttrW(fHDBC,
      SQL_ATTR_CURRENT_CATALOG, nil, 0, @aLen));
    if aLen > 0 then begin
      {$IFDEF UNICODE}
      SetLength(Result, aLen shr 1);
      CheckDbcError((fPlainDriver as TODBC3UnicodePlainDriver).SQLGetConnectAttrW(fHDBC,
        SQL_ATTR_CURRENT_CATALOG, Pointer(Result), aLen+2, @aLen));
      {$ELSE}
      SetLength(Buf, aLen shr 1);
      CheckDbcError((fPlainDriver as TODBC3UnicodePlainDriver).SQLGetConnectAttrW(fHDBC,
        SQL_ATTR_CURRENT_CATALOG, Pointer(Buf), aLen+2, @aLen));
      Result := PUnicodeToRaw(Pointer(Buf), aLen shr 1, ConSettings.CTRL_CP);
      {$ENDIF}
      inherited SetCatalog(Result);
    end;
  end;
end;

{**
  Converts the given SQL statement into the system's native SQL grammar.
  A driver may convert the JDBC sql grammar into its system's
  native SQL grammar prior to sending it; this method returns the
  native form of the statement that the driver would have sent.

  @param sql a SQL statement that may contain one or more '?'
    parameter placeholders
  @return the native form of this statement
}
function TZODBCConnectionW.NativeSQL(const SQL: string): string;
var NewLength: SQLINTEGER;
{$IFNDEF UNICODE}
  aSQL, nSQL: ZWideString;
{$ENDIF}
begin
  if SQL <> '' then begin
    {$IFNDEF UNICODE}
    aSQL := PRawToUnicode(Pointer(SQL), Length(SQL), ConSettings.CTRL_CP);
    SetLength(nSQL, Length(aSQL) shl 1);
    CheckDbcError(TODBC3UnicodePlainDriver(fPlainDriver).SQLNativeSqlW(fHDBC,
      Pointer(aSQL), Length(aSQL), Pointer(nSQL), Length(nSQL), @NewLength));
    Result := PUnicodeToRaw(Pointer(nSQL), NewLength, ConSettings^.ClientCodePage^.CP);
    {$ELSE}
    SetLength(Result, Length(SQL) shl 1);
    CheckDbcError(TODBC3UnicodePlainDriver(fPlainDriver).SQLNativeSqlW(fHDBC,
      Pointer(SQL), Length(SQL), Pointer(Result), Length(Result), @NewLength));
    SetLength(Result, NewLength);
    {$ENDIF}
  end else Result := '';
end;

{**
  Creates a <code>CallableStatement</code> object for calling
  database stored procedures.
  The <code>CallableStatement</code> object provides
  methods for setting up its IN and OUT parameters, and
  methods for executing the call to a stored procedure.

  <P><B>Note:</B> This method is optimized for handling stored
  procedure call statements. Some drivers may send the call
  statement to the database when the method <code>prepareCall</code>
  is done; others
  may wait until the <code>CallableStatement</code> object
  is executed. This has no
  direct effect on users; however, it does affect which method
  throws certain SQLExceptions.

  Result sets created using the returned CallableStatement will have
  forward-only type and read-only concurrency, by default.

  @param Name a procedure or function identifier
    parameter placeholders. Typically this  statement is a JDBC
    function call escape string.
  @param Info a statement parameters.
  @return a new CallableStatement object containing the
    pre-compiled SQL statement
}
function TZODBCConnectionW.PrepareCallWithParams(const Name: String;
  Info: TStrings): IZCallableStatement;
begin
  Result := TZODBCCallableStatementW.Create(Self, fHDBC, Name, Info);
end;

{**
  Creates a <code>PreparedStatement</code> object for sending
  parameterized SQL statements to the database.

  A SQL statement with or without IN parameters can be
  pre-compiled and stored in a PreparedStatement object. This
  object can then be used to efficiently execute this statement
  multiple times.

  <P><B>Note:</B> This method is optimized for handling
  parametric SQL statements that benefit from precompilation. If
  the driver supports precompilation,
  the method <code>prepareStatement</code> will send
  the statement to the database for precompilation. Some drivers
  may not support precompilation. In this case, the statement may
  not be sent to the database until the <code>PreparedStatement</code> is
  executed.  This has no direct effect on users; however, it does
  affect which method throws certain SQLExceptions.

  Result sets created using the returned PreparedStatement will have
  forward-only type and read-only concurrency, by default.

  @param sql a SQL statement that may contain one or more '?' IN
    parameter placeholders
  @param Info a statement parameters.
  @return a new PreparedStatement object containing the
    pre-compiled statement
}
function TZODBCConnectionW.PrepareStatementWithParams(const SQL: string;
  Info: TStrings): IZPreparedStatement;
begin
  if Closed then Open;
  Result := TZODBCPreparedStatementW.Create(Self, fHDBC, SQL, Info);
end;

procedure TZODBCConnectionW.ReleaseSavePoint(Index: Integer);
var S: UnicodeString;
begin
  S := cSavePointSyntaxW[fServerProvider][spqtCommit];
  if S <> '' then begin
    S := S+{$IFNDEF UNICODE}Ascii7ToUnicodeString{$ENDIF}(Self.FSavePoints[Index]);
    ExecuteImmediat(S, lcTransaction);
  end;
  FSavePoints.Delete(Index);
end;

procedure TZODBCConnectionW.RollBackTo(Index: Integer);
var S: UnicodeString;
begin
  S := cSavePointSyntaxW[fServerProvider][spqtRollback];
  if S <> '' then begin
    S := S+{$IFNDEF UNICODE}Ascii7ToUnicodeString{$ENDIF}(Self.FSavePoints[Index]);
    ExecuteImmediat(S, lcTransaction);
  end;
  FSavePoints.Delete(Index);
end;

{**
  Sets a catalog name in order to select
  a subspace of this Connection's database in which to work.
  If the driver does not support catalogs, it will
  silently ignore this request.
}
function TZODBCConnectionW.SavePoint(const AName: String): Integer;
var S: UnicodeString;
begin
  S := cSavePointSyntaxW[fServerProvider][spqtSavePoint];
  if S = '' then
    raise EZSQLException.Create(SUnsupportedOperation);
  S := S+{$IFNDEF UNICODE}Ascii7ToUnicodeString{$ENDIF}(AName);
  ExecuteImmediat(S, lcTransaction);
  Result := FSavePoints.Add(AName)+2;
end;

procedure TZODBCConnectionW.SetCatalog(const Catalog: string);
{$IFNDEF UNICODE}
var aCatalog: ZWideString;
{$ENDIF}
begin
  if Catalog <> inherited GetCatalog then begin
    {$IFNDEF UNICODE}
    aCatalog := PRawToUnicode(Pointer(Catalog), Length(Catalog), ZOSCodePage);
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_CURRENT_CATALOG,
      Pointer(aCatalog), Length(aCatalog) shl 1));
    {$ELSE}
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_CURRENT_CATALOG,
      Pointer(Catalog), Length(Catalog) shl 1));
    {$ENDIF}
    inherited SetCatalog(Catalog);
  end;
end;

{ TZODBCConnectionA }

{**
  Creates a <code>Statement</code> object for sending
  SQL statements to the database.
  SQL statements without parameters are normally
  executed using Statement objects. If the same SQL statement
  is executed many times, it is more efficient to use a
  <code>PreparedStatement</code> object.
  <P>
  Result sets created using the returned <code>Statement</code>
  object will by default have forward-only type and read-only concurrency.

  @param Info a statement parameters.
  @return a new Statement object
}
function TZODBCConnectionA.CreateStatementWithParams(
  Info: TStrings): IZStatement;
begin
  Result := TZODBCStatementA.Create(Self, fHDBC, Info);
end;

procedure TZODBCConnectionA.ExecuteImmediat(const SQL: RawByteString;
  LoggingCategory: TZLoggingCategory);
var STMT: SQLHSTMT;
begin
  if SQL = '' then
    Exit;
  STMT := nil;
  CheckDbcError(fPlainDriver.SQLAllocHandle(SQL_HANDLE_STMT, fHDBC, STMT));
  try
    CheckDbcError(TODBC3RawPlainDriver(fPlainDriver).SQLExecDirect(STMT,
      Pointer(SQL), Length(SQL)));
  finally
    if STMT <> nil then
      CheckDbcError(fPlainDriver.SQLFreeHandle(SQL_HANDLE_STMT, STMT));
  end;
end;

{**
  Returns the Connection's current catalog name.
  @return the current catalog name or null
}

function TZODBCConnectionA.GetCatalog: string;
var
  {$IFDEF UNICODE}
  Buf: RawByteString;
  {$ENDIF}
  aLen: SQLINTEGER;
begin
  Result := inherited GetCatalog;
  if Result = '' then begin
    CheckDbcError((fPlainDriver as TODBC3RawPlainDriver).SQLGetConnectAttr(fHDBC,
      SQL_ATTR_CURRENT_CATALOG, nil, 0, @aLen));
    if aLen > 0 then begin
      {$IFNDEF UNICODE}
      SetLength(Result, aLen shr 1);
      CheckDbcError((fPlainDriver as TODBC3RawPlainDriver).SQLGetConnectAttr(fHDBC,
        SQL_ATTR_CURRENT_CATALOG, Pointer(Result), aLen+1, @aLen));
      {$ELSE}
      SetLength(Buf, aLen shr 1);
      CheckDbcError((fPlainDriver as TODBC3RawPlainDriver).SQLGetConnectAttr(fHDBC,
        SQL_ATTR_CURRENT_CATALOG, Pointer(Buf), aLen+1, @aLen));
      Result := PRawToUnicode(Pointer(Buf), aLen, ConSettings.ClientCodePage.CP);
      {$ENDIF}
      inherited SetCatalog(Result);
    end;
  end;
end;

{**
  Converts the given SQL statement into the system's native SQL grammar.
  A driver may convert the JDBC sql grammar into its system's
  native SQL grammar prior to sending it; this method returns the
  native form of the statement that the driver would have sent.

  @param sql a SQL statement that may contain one or more '?'
    parameter placeholders
  @return the native form of this statement
}
function TZODBCConnectionA.NativeSQL(const SQL: string): string;
var NewLength: SQLINTEGER;
{$IFDEF UNICODE}
  aSQL, nSQL: RawByteString;
{$ENDIF}
begin
  if SQL <> '' then begin
    {$IFDEF UNICODE}
    aSQL := PUnicodeToRaw(Pointer(SQL), Length(SQL), ZOSCodePage);
    SetLength(nSQL, Length(aSQL) shl 1); //
    CheckDbcError(TODBC3RawPlainDriver(fPlainDriver).SQLNativeSql(fHDBC,
      Pointer(aSQL), Length(aSQL), Pointer(nSQL), Length(nSQL), @NewLength));
    Result := PRawToUnicode(Pointer(nSQL), NewLength, ZOSCodePage);
    {$ELSE}
    SetLength(Result, Length(SQL) shl 1); //
    CheckDbcError(TODBC3RawPlainDriver(fPlainDriver).SQLNativeSql(fHDBC,
      Pointer(SQL), Length(SQL), Pointer(Result), Length(Result), @NewLength));
    SetLength(Result, NewLength);
    {$ENDIF}
  end else Result := '';
end;

{**
  Creates a <code>CallableStatement</code> object for calling
  database stored procedures.
  The <code>CallableStatement</code> object provides
  methods for setting up its IN and OUT parameters, and
  methods for executing the call to a stored procedure.

  <P><B>Note:</B> This method is optimized for handling stored
  procedure call statements. Some drivers may send the call
  statement to the database when the method <code>prepareCall</code>
  is done; others
  may wait until the <code>CallableStatement</code> object
  is executed. This has no
  direct effect on users; however, it does affect which method
  throws certain SQLExceptions.

  Result sets created using the returned CallableStatement will have
  forward-only type and read-only concurrency, by default.

  @param Name a procedure or function identifier
    parameter placeholders. Typically this  statement is a JDBC
    function call escape string.
  @param Info a statement parameters.
  @return a new CallableStatement object containing the
    pre-compiled SQL statement
}
function TZODBCConnectionA.PrepareCallWithParams(const Name: String;
  Info: TStrings): IZCallableStatement;
begin
  Result := TZODBCCallableStatementA.Create(Self, fHDBC, Name, Info);
end;

{**
  Creates a <code>PreparedStatement</code> object for sending
  parameterized SQL statements to the database.

  A SQL statement with or without IN parameters can be
  pre-compiled and stored in a PreparedStatement object. This
  object can then be used to efficiently execute this statement
  multiple times.

  <P><B>Note:</B> This method is optimized for handling
  parametric SQL statements that benefit from precompilation. If
  the driver supports precompilation,
  the method <code>prepareStatement</code> will send
  the statement to the database for precompilation. Some drivers
  may not support precompilation. In this case, the statement may
  not be sent to the database until the <code>PreparedStatement</code> is
  executed.  This has no direct effect on users; however, it does
  affect which method throws certain SQLExceptions.

  Result sets created using the returned PreparedStatement will have
  forward-only type and read-only concurrency, by default.

  @param sql a SQL statement that may contain one or more '?' IN
    parameter placeholders
  @param Info a statement parameters.
  @return a new PreparedStatement object containing the
    pre-compiled statement
}
function TZODBCConnectionA.PrepareStatementWithParams(const SQL: string;
  Info: TStrings): IZPreparedStatement;
begin
  if Closed then Open;
  Result := TZODBCPreparedStatementA.Create(Self, fHDBC, SQL, Info);
end;

procedure TZODBCConnectionA.ReleaseSavePoint(Index: Integer);
var S: RawByteString;
begin
  S := cSavePointSyntaxA[fServerProvider][spqtCommit];
  if S <> '' then begin
    S := S+{$IFDEF UNICODE}UnicodeStringtoAscii7{$ENDIF}(FSavePoints[Index]);
    ExecuteImmediat(S, lcTransaction);
  end;
  FSavePoints.Delete(Index);
end;

procedure TZODBCConnectionA.RollBackTo(Index: Integer);
var S: RawByteString;
begin
  S := cSavePointSyntaxA[fServerProvider][spqtRollback];
  if S <> '' then begin
    S := S+{$IFDEF UNICODE}UnicodeStringtoAscii7{$ENDIF}(FSavePoints[Index]);
    ExecuteImmediat(S, lcTransaction);
  end;
  FSavePoints.Delete(Index);
end;

function TZODBCConnectionA.SavePoint(const AName: String): Integer;
var S: RawByteString;
begin
  S := cSavePointSyntaxA[fServerProvider][spqtSavePoint];
  if S = '' then
    raise EZSQLException.Create(SUnsupportedOperation);
  S := S+{$IFDEF UNICODE}UnicodeStringToAscii7{$ENDIF}(AName);
  ExecuteImmediat(S, lcTransaction);
  Result := FSavePoints.Add(AName)+2;
end;

{**
  Sets a catalog name in order to select
  a subspace of this Connection's database in which to work.
  If the driver does not support catalogs, it will
  silently ignore this request.
}
procedure TZODBCConnectionA.SetCatalog(const Catalog: string);
{$IFDEF UNICODE}
var aCatalog: RawByteString;
{$ENDIF}
begin
  if Catalog <> inherited GetCatalog then begin
    {$IFDEF UNICODE}
    aCatalog := PUnicodeToRaw(Pointer(Catalog), Length(Catalog), ZOSCodePage);
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_CURRENT_CATALOG,
      Pointer(aCatalog), Length(aCatalog)));
    {$ELSE}
    CheckDbcError(fPlainDriver.SQLSetConnectAttr(fHDBC, SQL_ATTR_CURRENT_CATALOG,
      Pointer(Catalog), Length(Catalog)));
    {$ENDIF}
    inherited SetCatalog(Catalog);
  end;
end;

var
  ODBCDriver: IZDriver;

initialization
  ODBCDriver := TZODBCDriver.Create;
  DriverManager.RegisterDriver(ODBCDriver);
finalization
  if DriverManager <> nil then
    DriverManager.DeregisterDriver(ODBCDriver);
  ODBCDriver := nil;

{$ENDIF ZEOS_DISABLE_ODBC} //if set we have an empty unit
end.
