unit simpledebug;

{$MODE OBJFPC}{$H+}

interface

  procedure Debug(S: String); overload;
  procedure Debug(S: String; Args: Array of Const); overload;
  procedure DebugLn(S: String); overload;
  procedure DebugLn(S: String; Args: Array of Const); overload;


implementation

Uses
  SysUtils;


procedure Debug(S: String);
begin
  Write(S);
end;


procedure Debug(S: String; Args: Array of Const);
begin
  Debug(Format(S, Args));
end;


procedure DebugLn(S: String);
begin
  WriteLn(S);
end;


procedure DebugLn(S: String; Args: Array of Const);
begin
  DebugLn(Format(S, Args));
end;


end.
