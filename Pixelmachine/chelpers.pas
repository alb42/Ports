unit chelpers;

interface

uses
  ctypes;

type
  ppcdouble = ^pcdouble;
  pctime_t  = ^ctime_t;
  ctime_t   = cint64;
  pvoid     = pointer;
  size_t = NativeUInt;

const
  RAND_MAX = 2147483647;


  function  IIF(condition: boolean; trueval: integer; falseval: integer): integer;
  function  IIF(condition: boolean; trueval: cdouble; falseval: cdouble): cdouble;

  function  calloc(num: size_t; size: size_t): pointer; inline;
  function  malloc(size: csize_t): pointer; inline;
  procedure free(p: pointer); inline;
  function  realloc(ptr: pointer; size: csize_t): pointer; inline;
  function  memset(ptr: pvoid; value: byte; num: size_t): pvoid; inline;

  function  strcpy(destination: PChar; const source: PChar): PChar; inline;
  function  atoi(c: PChar): Integer; inline;

  function  time(tloc: pctime_t): ctime_t; inline;

  procedure srand(seed: cunsigned); inline;
  function  rand: cint; inline;

implementation

uses
  SysUtils, DateUtils;


function  IIF(condition: boolean; trueval: integer; falseval: integer): integer;
begin
  if condition then IIF := trueval else IIF := falseval;
end;


function  IIF(condition: boolean; trueval: cdouble; falseval: cdouble): cdouble;
begin
  if condition then IIF := trueval else IIF := falseval;
end;


function  calloc(num: size_t; size: size_t): pointer; inline;
begin
  calloc := System.AllocMem(num * size);
end;


function  malloc(size: csize_t): pointer; inline;
begin
  malloc := System.GetMem(size);
end;


procedure free(p: pointer); inline;
begin
  if (p <> nil) then System.FreeMem(p);
end;


function  memset(ptr: pvoid; value: byte; num: size_t): pvoid; inline;
begin
  FillChar(ptr^, num, value);
  memset := ptr;
end;


function  realloc(ptr: pointer; size: csize_t): pointer; inline;
begin
  realloc := System.ReAllocMem(ptr, size);
end;


function  strcpy(destination: PChar; const source: PChar): PChar; inline;
begin
  strcpy := SysUtils.StrCopy(destination, source);
end;


function  atoi(c: PChar): Integer; inline;
begin
  atoi := StrToIntDef(c, -1);
end;


function  time(tloc: pctime_t): ctime_t; inline;
begin
  time := DateTimeToUnix(now);
  if assigned(tloc) then tloc^ := time;  
end;

// http://www.delphigroups.info/3/1/52500.html
var
  holdrand : LongInt = 1;

function rand: cint; inline;
begin
  holdrand := (((holdrand * 214013 + 2531011) shr 16) and $7fff);
  exit( holdrand );
end;


procedure srand(seed: cunsigned); inline;
begin
  holdrand := LongInt(seed);
end;

end.
