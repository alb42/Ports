unit sjrnd;

interface

uses
  ctypes;

//function  sj_srand(seed: cunsignedlonglong): pointer;
function  sj_srand(seed: cuint64): pointer;
function  sj_rand(handle: pointer): cdouble;
procedure sj_drand(handle: pointer);

implementation

uses
  chelpers;

function  sj_srand(seed: cuint64): pointer;
var
  a : pcuint64;
begin
  a := pcuint64(malloc(sizeof(pcuint64^)));
  a^ := seed;
  exit(a);
end;

function  sj_rand(handle: pointer): cdouble;
var
  a : pcuint64;
  b : cuint64;
begin
  a := pcuint64(handle);
  a^ := a^ * cuint64(7212336353) + cuint64(8963315421273233617);
  b  := a^ and cuint64($3fffffffffffffff) or cuint64($3ff0000000000000);
  exit(b - 1.0)
end;

procedure sj_drand(handle: pointer);
begin
  chelpers.free(handle);
end;

end.
