{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{            Written by Sergey Merkuriev                  }
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

{*********************************************************}
{                                                         }
{ TZPgEventAlerter, Asynchronous notifying.               }
{   By Ivan Rog - 2010                                    }
{                                                         }
{ Contributors:                                           }
{   Silvio Clecio - http://silvioprog.com.br              }
{                                                         }
{*********************************************************}

{ constributor(s):
  EgonHugeist
}
unit ZPgEventAlerter;

interface
{$I ZComponent.inc}
{$IFNDEF ZEOS_DISABLE_POSTGRESQL} //if set we have an empty unit
uses
  SysUtils, Classes,
  {$IFDEF TLIST_IS_DEPRECATED}ZSysUtils,{$ENDIF}
  ZDbcPostgreSql, ZPlainPostgreSqlDriver, ZAbstractConnection, ZAbstractRODataset
  {$IFNDEF WITH_RAWBYTESTRING},ZCompatibility{$ENDIF}, ZClasses;

type
  TZPgNotifyEvent = procedure(Sender: TObject; Event: string;
    ProcessID: Integer; Payload: string) of object;

  { TZPgEventAlerter }

  TZPgEventAlerter = class (TAbstractActiveConnectionLinkedComponent)
  private
    FEvents      : TStrings;

    FTimer       : TZThreadTimer;
    FNotifyFired : TZPgNotifyEvent;

    FProcessor   : TZPgEventAlerter; //processor component - it will actually handle notifications received from DB
    //if processor is not assignet - component is handling notifications by itself
    FChildAlerters :{$IFDEF TLIST_IS_DEPRECATED}TZSortedList{$ELSE}TList{$ENDIF}; //list of TZPgEventAlerter that have our component attached as processor
    FChildEvents : TStrings; //list of actual events to be handled - gathered from events of all childe
  protected
    procedure SetActive     (Value: Boolean); override;
    function  GetInterval   : Cardinal;
    procedure SetInterval   (Value: Cardinal);
    procedure SetEvents     (Value: TStrings);
    procedure SetConnection (Value: TZAbstractConnection); override;
    procedure TimerTick;
    procedure CheckEvents;
    procedure OpenNotify;
    procedure CloseNotify;

    procedure SetProcessor(Value: TZPgEventAlerter);
    procedure AddChildAlerter(Child: TZPgEventAlerter);
    procedure RemoveChildAlerter(Child: TZPgEventAlerter);
    procedure HandleNotify(Notify: PZPostgreSQLNotify); //launching OnNotify event fo Self and all child components (if event name is matched)
    procedure SetChildEvents     ({%H-}Value: TStrings);
    procedure RefreshEvents; //gathering all events from all child components (no duplicates), also propagating these events "down" to our processor
  public
    constructor Create     (AOwner: TComponent); override;
    destructor  Destroy; override;
  published
    property Connection;
    property Active;
    property Events:     TStrings         read FEvents       write SetEvents;
    property Interval:   Cardinal         read GetInterval   write SetInterval    default 250;
    property OnNotify:   TZPgNotifyEvent  read FNotifyFired  write FNotifyFired;
    property Processor:     TZPgEventAlerter          read FProcessor       write SetProcessor; //property to assign processor handling notifications
    property ChildEvents:   TStrings         read FChildEvents write SetChildEvents; //read onlu property to keep all events in one place
  end;

{$ENDIF ZEOS_DISABLE_POSTGRESQL} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_POSTGRESQL} //if set we have an empty unit


uses ZMessages
{$IFDEF UNICODE},ZEncoding{$ENDIF}
{$IFDEF WITH_UNITANSISTRINGS},AnsiStrings{$ENDIF};

{ TZPgEventAlerter }

constructor TZPgEventAlerter.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);
  FEvents := TStringList.Create;
  FChildAlerters := {$IFDEF TLIST_IS_DEPRECATED}TZSortedList{$ELSE}TList{$ENDIF}.Create;
  FChildEvents := TStringList.Create;
  with TStringList(FEvents) do
  begin
    Duplicates := dupIgnore;
  end;

  with TStringList(FChildEvents) do
  begin
    Duplicates := dupIgnore;
  end;

  FTimer         := TZThreadTimer.Create(TimerTick, 250, False);
  FActive        := False;
  if (csDesigning in ComponentState) and Assigned(AOwner) then
    for I := AOwner.ComponentCount - 1 downto 0 do
      if AOwner.Components[I] is TZAbstractConnection then begin
        FConnection := AOwner.Components[I] as TZAbstractConnection;
        Break;
      end;
end;

destructor TZPgEventAlerter.Destroy;
begin
  if FProcessor = nil then
    CloseNotify;
  FEvents.Free;
  FTimer.Free;
  FChildAlerters.Free;
  FChildEvents.Free;
  inherited Destroy;
end;

procedure TZPgEventAlerter.SetInterval(Value: Cardinal);
begin
  FTimer.Interval := Value;
end;

function TZPgEventAlerter.GetInterval: Cardinal;
begin
  Result := FTimer.Interval;
end;

procedure TZPgEventAlerter.SetEvents(Value: TStrings);
var
  I: Integer;
begin
  FEvents.Assign(Value);

  for I := 0 to FEvents.Count -1 do
    FEvents[I] := Trim(FEvents[I]);
  RefreshEvents; //we must propagate events down to our processor
end;

procedure TZPgEventAlerter.SetActive(Value: Boolean);
begin
  if FActive <> Value then
    if FProcessor = nil then
      if Value then begin
        RefreshEvents;
        OpenNotify;
      end else
        CloseNotify
    else begin //we have processor attached - we dont need to open or close notifications
      FActive := Value;
      FProcessor.RefreshEvents;
    end;
end;

procedure TZPgEventAlerter.SetConnection(Value: TZAbstractConnection);
begin
  if FConnection <> Value then begin
    if FProcessor = nil then //we are closing notifiers only whern there is no processor attached
      CloseNotify;
    FConnection := Value;
  end;
end;

procedure TZPgEventAlerter.TimerTick;
begin
  if not FActive or (FProcessor <> nil)
  then FTimer.Enabled := False
  else CheckEvents;
end;

procedure TZPgEventAlerter.OpenNotify;
var
  I        : Integer;
  Tmp      : RawByteString;
  Handle   : TPGconn;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : TZPostgreSQLPlainDriver;
  Res: TPGresult;
begin
  if not Boolean(Pos('postgresql', FConnection.Protocol)) then
    raise EZDatabaseError.Create(Format(SUnsupportedProtocol, [FConnection.Protocol]));
  if FActive then
    Exit;
  if not Assigned(FConnection) then
    Exit;
  if ((csLoading in ComponentState) or (csDesigning in ComponentState)) then
    Exit;
  if not FConnection.Connected then begin
    FActive := False;
    Exit;
  end;
  ICon     := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle   := ICon.GetPGconnAddress^;
  PlainDRV := ICon.GetPlainDriver;
  if Handle = nil then
    Exit;
  for I := 0 to FChildEvents.Count-1 do begin
    {$IFDEF UNICODE}
    Tmp := ZUnicodeToRaw(FChildEvents.Strings[I], ICon.GetConSettings.ClientCodePage.CP);
    {$ELSE}
    Tmp := FChildEvents.Strings[I];
    {$ENDIF}
    Tmp := 'listen ' + Tmp;
    Res := PlainDRV.PQExec(Handle, Pointer(Tmp));
    if (PlainDRV.PQresultStatus(Res) <> TZPostgreSQLExecStatusType(PGRES_COMMAND_OK)) then begin
      PlainDRV.PQclear(Res);
      Exit;
    end;
    PlainDRV.PQclear(Res);
  end;
  FActive        := True;
  FTimer.Enabled := True;
end;

procedure TZPgEventAlerter.CloseNotify;
var
  I        : Integer;
  Tmp      : RawByteString;
  Handle   : TPGconn;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : TZPostgreSQLPlainDriver;
  Res: TPGresult;
begin
  if not FActive then
    Exit;
  FActive        := False;
  FTimer.Enabled := False;
  if not FConnection.Connected then Exit;
  ICon           := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle         := ICon.GetPGconnAddress^;
  PlainDRV       := ICon.GetPlainDriver;
  if Handle = nil then
    Exit;
  for I := 0 to FChildEvents.Count-1 do begin
    {$IFDEF UNICODE}
    Tmp := ZUnicodeToRaw(FChildEvents.Strings[I], ICon.GetConSettings.ClientCodePage.CP);
    {$ELSE}
    Tmp := FChildEvents.Strings[I];
    {$ENDIF}
    Tmp := 'unlisten ' + Tmp;
    Res := PlainDRV.PQExec(Handle, Pointer(Tmp));
    if (PlainDRV.PQresultStatus(Res) <> TZPostgreSQLExecStatusType(PGRES_COMMAND_OK)) then begin
      PlainDRV.PQclear(Res);
      Exit;
    end;
    PlainDRV.PQclear(Res);
  end;
end;

procedure TZPgEventAlerter.CheckEvents;
var
  Notify: PZPostgreSQLNotify;
  Handle   : TPGconn;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : TZPostgreSQLPlainDriver;
begin
  ICon      := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle    := ICon.GetPGconnAddress^;
  if Handle = nil then begin
    FTimer.Enabled := False;
    FActive := False;
    Exit;
  end;
  if not FConnection.Connected then begin
    CloseNotify;
    Exit;
  end;
  PlainDRV  := ICon.GetPlainDriver;
  while PlainDRV.PQisBusy(Handle) = 1 do //see: https://sourceforge.net/p/zeoslib/tickets/475/
    Sleep(1);

  if PlainDRV.PQconsumeInput(Handle)=1 then
    while True do begin
      Notify := PZPostgreSQLNotify(PlainDRV.PQnotifies(Handle));
      if Notify = nil then
        Break;
      HandleNotify(Notify);
      PlainDRV.PQFreemem(Notify);
    end;
end;

procedure TZPgEventAlerter.HandleNotify(Notify: PZPostgreSQLNotify);
var
  i: Integer;
  CurrentChild: TZPgEventAlerter;
begin
  if Assigned(FNotifyFired) and (FEvents.IndexOf(String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname)) <> -1) then
    FNotifyFired(Self, String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname), Notify{$IFDEF OLDFPC}^{$ENDIF}.be_pid,String(Notify{$IFDEF OLDFPC}^{$ENDIF}.payload));

  for I := 0 to FChildAlerters.Count-1 do //propagating event to child listeners
  begin
    CurrentChild :=TZPgEventAlerter(FChildAlerters[i]);
    if CurrentChild.Active and (CurrentChild.ChildEvents.IndexOf(String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname)) <> -1) then //but only active ones
      CurrentChild.HandleNotify(Notify);
  end;
end;

procedure TZPgEventAlerter.SetProcessor(Value: TZPgEventAlerter);
begin
  if FProcessor <> Value then begin
    if FProcessor <> nil then //remove assignment from old processor
      FProcessor.RemoveChildAlerter(Self);
    FProcessor := Value;
    if FProcessor <> nil then begin//add assignment to new processor
      if FProcessor.Connection <> FConnection then
        raise Exception.Create('Cannot set processor with different connection');
      FProcessor.AddChildAlerter(Self);
    end;
  end;
end;

procedure TZPgEventAlerter.RefreshEvents;
var
  i,j: integer;
  CurrentChild: TZPgEventAlerter;
begin
  FChildEvents.Clear;
  for I := 0 to FChildAlerters.Count-1 do begin
    CurrentChild := TZPgEventAlerter(FChildAlerters[i]);
    if CurrentChild.Active or ((csLoading in ComponentState) or (csDesigning in ComponentState)) then
       //gathering vent namse from all childs
      for j := 0 to CurrentChild.ChildEvents.Count-1 do
        if FChildEvents.IndexOf(CurrentChild.ChildEvents.Strings[j]) = -1 then
          FChildEvents.Add(CurrentChild.ChildEvents.Strings[j]);
  end;

  for i := 0 to Events.Count-1 do
    if FChildEvents.IndexOf(Events.Strings[i]) = -1 then
      FChildEvents.Add(Events.Strings[i]);

  if FProcessor <> nil then  //refreshing eventrs in our processor
    FProcessor.RefreshEvents
  else if Active then begin//refreshing listeners after change of events - to make sure we will listen for everything
    Active := False;
    Active := True;
  end;
end;

procedure TZPgEventAlerter.AddChildAlerter(Child: TZPgEventAlerter);
begin
  FChildAlerters.Add(Child);
  RefreshEvents;
end;

procedure TZPgEventAlerter.RemoveChildAlerter(Child: TZPgEventAlerter);
var
  i: integer;
begin
  i := FChildAlerters.IndexOf(Child);
  FChildAlerters.Delete(i);
  RefreshEvents;
end;

procedure TZPgEventAlerter.SetChildEvents(Value: TStrings);
begin
  Exit;
end;
{$ENDIF ZEOS_DISABLE_POSTGRESQL} //if set we have an empty unit
end.
