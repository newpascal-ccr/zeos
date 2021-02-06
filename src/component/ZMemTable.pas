{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{               Abstract MemTable component               }
{                                                         }
{          Originally written by EgonHugeist              }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2020 Zeos Development Group       }
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
{   https://zeoslib.sourceforge.io/ (FORUM)               }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZMemTable;

{$I ZComponent.inc}

interface

uses
  SysUtils, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF}
  {$IFDEF NO_UNIT_CONTNRS}ZClasses{$ELSE}Contnrs{$ENDIF},
  ZCompatibility,
  ZDbcIntfs,
  ZAbstractDataset, ZAbstractRODataset, ZAbstractConnection, ZDatasetUtils;

type
  TZAbstractMemTable = class(TZAbstractRWDataSet)
  protected
    FLocalConSettings: TZConSettings;
    FCharacterSet: TZCodePage;
    function CreateResultSet(const SQL: string; MaxRows: Integer):
      IZResultSet; override;
    function CreateStatement(const SQL: string; Properties: TStrings):
      IZPreparedStatement; override;
    procedure CheckSQLQuery; override;
    procedure CheckConnected; override;
    procedure InternalRefresh; override;
    procedure InternalPrepare; override;
    /// <summary>Sets database connection object.</summary>
    /// <param>"Value" a database connection object.</param>
    procedure SetConnection(Value: TZAbstractConnection); override;
  end;

implementation

uses ZMessages, ZEncoding,
  ZDbcStatement, ZDbcMetadata, ZDbcResultSetMetadata, ZDbcUtils,
  ZDbcCachedResultSet,
  {$IFDEF MSEgui}mclasses, mdb{$ELSE}DB{$ENDIF};

type
  TZMemResultSetPreparedStatement = Class(TZBeginnerPreparedStatement,
    IZPreparedStatement)
  private
    FColumnList: TObjectList;
  public
    constructor Create(ConSettings: PZConSettings;
      {$IFDEF AUTOREFCOUNT}const{$ENDIF}AColumnList: TObjectList;
      {$IFDEF AUTOREFCOUNT}const{$ENDIF}Info: TStrings);
    destructor Destroy; override;
  public
    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;
  End;

{ TZMemResultSetPreparedStatement }

{$IFDEF FPC} {$PUSH} {$WARN 5024 off : Parameter "Info" not used} {$ENDIF}
constructor TZMemResultSetPreparedStatement.Create(
  ConSettings: PZConSettings;
  {$IFDEF AUTOREFCOUNT}const{$ENDIF}AColumnList: TObjectList;
  {$IFDEF AUTOREFCOUNT}const{$ENDIF}Info: TStrings);
begin
  Self.ConSettings := ConSettings;
  FColumnList := TObjectList.Create;
  CopyColumnsInfo(AColumnList, FColumnList);
end;
{$IFDEF FPC} {$POP} {$ENDIF}

destructor TZMemResultSetPreparedStatement.Destroy;
begin
  inherited;
  FreeAndNil(FColumnList);
end;

function TZMemResultSetPreparedStatement.ExecutePrepared: Boolean;
begin
  LastResultSet := ExecuteQueryPrepared;
  Result := True;
end;

function TZMemResultSetPreparedStatement.ExecuteQueryPrepared: IZResultSet;
var VirtualResultSet: TZVirtualResultSet;
begin
  VirtualResultSet := TZVirtualResultSet.CreateWithColumns(FColumnList, '', ConSettings);
  Result := VirtualResultSet;
  VirtualResultSet.SetType(GetResultSetType);
  VirtualResultSet.SetConcurrency(GetResultSetConcurrency);
end;

function TZMemResultSetPreparedStatement.ExecuteUpdatePrepared: Integer;
begin
  Result := 0;
end;

{ TZAbstractMemTable }

procedure TZAbstractMemTable.CheckConnected;
begin
  // NOOP
end;

procedure TZAbstractMemTable.CheckSQLQuery;
begin
  if FieldDefs.Count = 0 then
    raise EZDataBaseError.Create(SQueryIsEmpty);
end;

{$IFDEF FPC} {$PUSH} {$WARN 5024 off : Parameter "SQL" not used} {$ENDIF}
function TZAbstractMemTable.CreateResultSet(const SQL: string;
  MaxRows: Integer): IZResultSet;
var RS: IZCachedResultSet;
begin
  if (FConnection <> nil)
  then FControlsCodePage := Connection.ControlsCodePage
  else FControlsCodePage := cDynamic;
  FCharacterSet.Encoding := {$IFDEF UNICODE}ceUTF16{$ELSE}{$IFDEF FPC}ceUTF8{$ELSE}ceAnsi{$ENDIF}{$ENDIF};
  {$IFDEF WITH_DEFAULTSYSTEMCODEPAGE}
  FCharacterSet.CP := {$IFDEF UNICODE}zCP_UTF8{$ELSE}DefaultSystemCodePage{$ENDIF};
  {$ELSE}
  FCharacterSet.CP := {$IFDEF FPC}zCP_UTF8{$ELSE}ZOSCodePage{$ENDIF};
  {$ENDIF}
  Statement := CreateStatement('', Properties);
  if RequestLive then
    Statement.SetResultSetConcurrency(rcUpdatable)
  else
    Statement.SetResultSetConcurrency(rcReadOnly);
  Statement.SetFetchDirection(fdForward);
  Statement.SetResultSetType(rtScrollInsensitive);
  if MaxRows > 0 then
    Statement.SetMaxRows(MaxRows);
  Result := Statement.ExecuteQueryPrepared;
  Result.QueryInterface(IZCachedResultSet, RS);
  CachedResultSet := RS;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{$IFDEF FPC} {$PUSH} {$WARN 5024 off : Parameter "SQL" not used} {$ENDIF}
function TZAbstractMemTable.CreateStatement(const SQL: string;
  Properties: TStrings): IZPreparedStatement;
var ColumnList: TObjectList;
    I: Integer;
    Current: TFieldDef;
    ColumnInfo: TZColumnInfo;
    AConSettings: PZConSettings;
begin
  FConSettings := @FLocalConSettings;
  ColumnList := TObjectList.Create(True);
  try
    for I := 0 to FieldDefs.Count - 1 do begin
      Current := FieldDefs[I];
      if not Current.InternalCalcField then begin
        ColumnInfo := TZColumnInfo.Create;
        ColumnInfo.ColumnType := ConvertDatasetToDbcType(Current.DataType);
        ColumnInfo.ColumnName := Current.Name;
        ColumnInfo.Precision := Current.Size;
        ColumnInfo.Writable := RequestLive;
        ColumnInfo.ReadOnly := not RequestLive;
        if Current.DataType in [ftBCD, ftFmtBCD] then
          ColumnInfo.Scale := Current.Size
        else if ColumnInfo.ColumnType in [stUnicodeString, stUnicodeStream] then
          ColumnInfo.ColumnCodePage := zCP_UTF16
        else if ColumnInfo.ColumnType in [stString, stAsciiStream] then
          {$IFDEF FPC}
          ColumnInfo.ColumnCodePage := {$IFDEF WITH_DEFAULTSYSTEMCODEPAGE}DefaultSystemCodePage{$ELSE}zCP_UTF8{$ENDIF};
          {$ELSE}
          ColumnInfo.ColumnCodePage := {$IFDEF UNICODE}zCP_UTF8{$ELSE}ZOSCodePage{$ENDIF};
          {$ENDIF}
        ColumnInfo.ColumnLabel := Current.DisplayName;
        ColumnList.Add(ColumnInfo);
      end;
    end;
    FLocalConSettings.ClientCodePage := @FCharacterSet;
    AConSettings := @FLocalConSettings;
    AConSettings.W2A2WEncodingSource := encDB_CP;
    Result := TZMemResultSetPreparedStatement.Create(AConSettings, ColumnList, Properties);
  finally
    FreeAndNil(ColumnList);
  end;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

procedure TZAbstractMemTable.InternalPrepare;
begin
  //NOOP
end;

procedure TZAbstractMemTable.InternalRefresh;
begin
  //NOOP
end;

procedure TZAbstractMemTable.SetConnection(Value: TZAbstractConnection);
begin
  if FConnection <> Value then begin
    if Value = nil then begin
      FConnection.UnregisterComponent(Self);
      FormatSettings.SetParent(nil);
    end else begin
      FormatSettings.SetParent(Value.FormatSettings);
      Value.RegisterComponent(Self);
    end;
    FConnection := Value;
  end;
end;

end.
