unit pixelina;

{$MODE OBJFPC}{$H+}
{.$DEFINE SPILL_GUTS}

interface

uses
  ctypes, chelpers, Classes, collision, SDL, syncobjs;

type
  TThreadFunc = function(data: pointer ): cint; cdecl;

  { TMyThread }

  TMyThread = class(TThread)
  protected
    procedure Execute; override;
  private
    Func: TThreadFunc;
    Data: Pointer;
  end;


type
  PPSDL_Thread      = ^TMyThread;

const
  TERDIV            =  8;       // terrain divisions (powers of 2 ONLY!)
  TERSECS           = 16;       // sections per division, this will work out to (TERDIV*TERSECS+1)^3 cubes!!
  FALLOFF           = 600000.0;

  PH_TERDIV         =  1;       // terrain divisions (powers of 2 ONLY!)
  PH_TERSECS        = 15;       // sections per division
  PH_FALLOFF        = 30000.0;


  BSIZE             = (TERDIV*TERSECS+1);
  SQSIZE            = (1000.0/cdouble(BSIZE));

  PH_BSIZE          = (PH_TERDIV*PH_TERSECS+1);
  PH_SQSIZE         = (1000.0/cdouble(PH_BSIZE));

  PREVIEWW          = 80;
  PREVIEWH          = 60;

  MAXBOUNCE         = 20;

  XY                = 0;
  XZ                = 1;
  YZ                = 2;

  SCATTER_VAL       = 0.000003;

  SUNS              = 1;

  SPHERES           = 80;
  PH_SPHERES        =  6;

  PATCHDIM          = 250;
  PHOTONRADIUS      = 1.0;

  PX0               = 499.0;
  PX1               = 751.0;
  PY0               = 499.0;
  PY1               = 751.0;
  PZ0               = 499.0;
  PZ1               = 751.0;

  NO_PIXEL          = -1;

  MODE_CAMRAY       = 0;
  MODE_LIGHTTEST    = 1;
  MODE_PHOTON       = 2;

  INVRAND = (cdouble(2.0)/cdouble(RAND_MAX));


type
  TPIXELMACHINE = class
  type
    PRENDER_ARGS = ^TRENDER_ARGS;
    TRENDER_ARGS =
    record
      cam       : TVECTOR;
      tar       : TVECTOR;
      w,h       : cint;
      l,r,t,b   : cint;
      quiet     : cbool;
      lock      : TCriticalSection;
      threadid  : cint;
      pm        : TPIXELMACHINE;
    end;
    PPHOTON_ARGS = ^TPHOTON_ARGS;
    TPHOTON_ARGS =
    record
      c         : TCOLOR;
      ration    : cint;
      seed      : cunsigned;
      lock      : TCriticalSection;
      threadid  : cint;
      pm        : TPIXElMACHINE;
    end;
    PPATCH = ^TPATCH;
    TPATCH =
    record
      v         : TVECTOR;
      i         : cint;
      n         : PPATCH;
    end;
    PREG = ^TREG;
    TREG =
    record
      l,r,t,b   : cint;
    end;
   private
   public
    //    P *patch[PATCHDIM][PATCHDIM][PATCHDIM];
    patch       : array[0..Pred(PATCHDIM), 0..Pred(PATCHDIM), 0..Pred(PATCHDIM)] of PPATCH;
    tempx,
    tempy,
    tempz       : cint;
    terrain     : ppcdouble;
    img         : PByte;
    dimg        : PCOLOR;
    w           : cint;
    h           : cint;
    multis      : cint;
    threads     : cint;
    photons     : cint;
    frames      : cint;
    seed        : cunsigned;
    c_terdiv    : cint;
    c_tersecs   : cint;
    c_falloff   : cdouble;
    c_bsize     : cint;
    c_sqsize    : cdouble;
    c_spheres   : cint;
    blocks      : PPPCOLOR;
    blocksize   : cdouble;
    tarw        : cdouble;
    pixpitch    : cdouble;
    subpitch    : cdouble;
    sun         : array [0..Pred(SUNS)] of TVECTOR;
    sphere      : PSPHERE;
    spheremania : cbool;
    busy        : pcbool;
    running     : cbool;
    cam         : TVECTOR;
    tar         : TVECTOR;
    regions     : PREG;
    reg_count   : cint;
    reg_alloc   : cint;
    lock        : TCriticalSection;
    cancel      : cbool;
    statustext  : string; // array[0..Pred(200)] of char;
   public
    constructor Create;
    destructor  Destroy; override;

    procedure init(_seed: cunsigned; _w: cint; _h: cint; _multis: cint; _threads: cint; _photons: cint);
    procedure build_terrain();
    procedure generate_objects();
    procedure run();
    procedure savebmp( const _filename: PChar; _w: cint; _h: cint );
    procedure render( _w: cint; _h: cint; _quiet: cbool );
    procedure push_region( _ra: PRENDER_ARGS );
    function  pop_region( _rect: PSDL_RECT ): cbool;
    function  render_thread( _data: pointer ): cint;
    function  photon_thread( _data: pointer ): cint;
    procedure render_photons( _cam: TVECTOR; _tar: TVECTOR; _w: cint; _h: cint; _quiet: cbool );
    function  raytrace( var _color: TCOLOR; const _cam: TVECTOR; const _ray: TVECTOR; _mode: cint; _bounce : cint; _pixelindex: cint = NO_PIXEL ): TCOLOR;

    procedure attach( _pixelindex: cint; const _hit : TVECTOR);
    procedure feed( const _c: TCOLOR; const _hit: TVECTOR );
  end;


function CreateThread(Func: TThreadFunc; Data: Pointer): TMyThread;

implementation

uses
  Sysutils, sjrnd, SimpleDebug;


{ TMyThread }

procedure TMyThread.Execute;
begin
  Func(Data);
  Terminate;
end;

function CreateThread(Func: TThreadFunc; Data: Pointer): TMyThread;
begin
  Result := TMyThread.Create(True);
  Result.FreeOnTerminate := False;
  Result.Func := Func;
  Result.Data := Data;
  Result.Start;
end;


function  ext_render_thread( data: pointer ): cint; cdecl; forward;
function  ext_photon_thread( data: pointer ): cint; cdecl; forward;


function MINVAL(a: cint; b: cint): cint; inline;
begin
  if (a < b) then exit(a) else exit(b);
end;


function MAXVAL(a: cint; b: cint): cint; inline;
begin
  if (a > b) then exit(a) else exit(b);
end;



constructor TPIXELMACHINE.Create;
begin
  inherited;

  cancel := false;
  running := false;
  spheremania := false;
  blocks := nil;
  terrain := nil;
  sphere := nil;
  img := nil;
  dimg := nil;
  reg_count := 0;
  reg_alloc := 8;
  regions := PREG(malloc(sizeof(TREG)*reg_alloc));
  lock := TCriticalSection.Create;
end;


destructor TPIXELMACHINE.Destroy;
var
  i,j: cint;
begin
  Lock.Free;

  chelpers.free(regions);

  for i := 0 to Pred(c_bsize) do
  begin
    for j := 0 to pred(c_bsize) do
      chelpers.free(blocks[i][j]);
    chelpers.free(terrain[i]);
    chelpers.free(blocks[i]);
  end;
  chelpers.free(terrain);
  chelpers.free(blocks);
  chelpers.free(sphere);

  if assigned(img)
    then chelpers.free(img);

  inherited;
end;


procedure TPIXELMACHINE.init(_seed: cunsigned; _w: cint; _h: cint; _multis: cint; _threads: cint; _photons: cint);
var
  i,j: cint;
begin
  seed := _seed;
  w := _w;
  h := _h;
  multis := _multis;
  threads := _threads;
  photons := _photons;
  frames := 1;

  if not ( photons <> 0) then
  begin
    c_terdiv  := TERDIV;
    c_tersecs := TERSECS;
    c_falloff := FALLOFF;
    c_bsize   := BSIZE;
    c_sqsize  := SQSIZE;
    c_spheres := SPHERES;
  end
  else
  begin
    c_terdiv  := PH_TERDIV;
    c_tersecs := PH_TERSECS;
    c_falloff := PH_FALLOFF;
    c_bsize   := PH_BSIZE;
    c_sqsize  := PH_SQSIZE;
    c_spheres := PH_SPHERES;
  end;

  blocks := PPPCOLOR(malloc(c_bsize*sizeof(blocks^)));
  terrain := ppcdouble(malloc(c_bsize*sizeof(terrain^)));
  for i := 0 to Pred(c_bsize) do
  begin
    blocks[i]  := PPCOLOR(malloc(c_bsize*sizeof(blocks^^)));
    terrain[i] := pcdouble(malloc(c_bsize*sizeof(terrain^^)));
    for j := 0 to Pred(c_bsize) do
      blocks[i][j] := PCOLOR(calloc(c_bsize,sizeof(blocks^^^)));
  end;
  sphere := PSPHERE(calloc(c_spheres+1, sizeof(TSPHERE)));

  blocksize := 1000.0 / cdouble(c_bsize);
  srand(seed);

  build_terrain();
  generate_objects();

  //strcpy(statustext,'Ready');
  statustext := 'Ready';
end;


procedure TPIXELMACHINE.build_terrain();
var
  i,j,k: cint;
  tdiv : cint;
begin
  if not( photons <> 0 ) then
  begin
    tdiv := c_terdiv;
    i := 0;

    while (i < c_bsize) do // ;i+=div)
    begin
      j := 0;
      while (j < c_bsize) do // ;j+=div)
      begin
        terrain[i][j] := cdouble(rand() mod 1000)*0.33-200.0;
        j := j + tdiv;
      end;
      i := i + tdiv;
    end;

    while ( tdiv > 1 ) do
    begin
      i := tdiv div 2;
      while (i < c_bsize) do // ;i+=div)
      begin
        j := tdiv div 2;
        while (j < c_bsize) do // ;j+=div)
        begin
          terrain[i][j] := (terrain[i-tdiv div 2][j-tdiv div 2] + terrain[i-tdiv div 2][j+tdiv div 2] + terrain[i+tdiv div 2][j-tdiv div 2] + terrain[i+tdiv div 2][j+ tdiv div 2])*0.25;
          j := j + tdiv;
        end;
        i := i + tdiv;
      end;


      i := 0;
      while (i < c_bsize) do //;i+=div/2)
      begin
        j := 0;
        while (j < c_bsize) do // ;j+=div/2)
        begin
          if ( (i+j) mod tdiv <> 0) then
          begin
            if ( i = 0 )
            then terrain[i][j] := (                           terrain[i+tdiv div 2][j] + terrain[i][j-tdiv div 2] + terrain[i][j+tdiv div 2])*0.33333
            else
            if ( i = c_bsize-1 )
            then terrain[i][j] := (terrain[i-tdiv div 2][j]                            + terrain[i][j-tdiv div 2] + terrain[i][j+tdiv div 2])*0.33333
            else
            if ( j = 0 )
            then terrain[i][j] := (terrain[i-tdiv div 2][j] + terrain[i+tdiv div 2][j]                            + terrain[i][j+tdiv div 2])*0.33333
            else
            if ( j = c_bsize-1 )
            then terrain[i][j] := (terrain[i-tdiv div 2][j] + terrain[i+tdiv div 2][j] + terrain[i][j-tdiv div 2]                           )*0.33333
            else terrain[i][j] := (terrain[i-tdiv div 2][j] + terrain[i+tdiv div 2][j] + terrain[i][j-tdiv div 2] + terrain[i][j+tdiv div 2])*0.25;
          end;
          j := j + (tdiv div 2);
        end;
        i := i +  (tdiv div 2);
      end;

      tdiv := tdiv div 2;
    end;
  end;

  for k := 0 to Pred(c_bsize) do
    for i := 0 to Pred(c_bsize) do
      for j := 0 to Pred(c_bsize) do
      begin
        if ( (k=0) or (photons <> 0) ) then
        begin
          blocks[i][j][k].r := cdouble(rand() mod 80) / 255.0 + 0.70;
          blocks[i][j][k].g := cdouble(rand() mod 60) / 255.0 + 0.60;
          blocks[i][j][k].b := cdouble(rand() mod 40) / 255.0 + 0.20;
          blocks[i][j][k].a := 1.0; //(double)(rand()%100+1)*0.01;
        end
        else
        if ( (i > (c_bsize*2) div 5) and ( i < (c_bsize*3) div 5) and (j > (c_bsize*2) div 5) and (j < (c_bsize*3) div 5) ) then// shiny area!
        begin
          if ( k<c_bsize div 5 )
          then blocks[i][j][k] := blocks[i][j][k-1]
          else
          begin
            blocks[i][j][k].r := 0.0;
            blocks[i][j][k].g := 0.0;
            blocks[i][j][k].b := 0.0;
            blocks[i][j][k].a := 0.0;
          end;
        end
        else
        if ( terrain[i][j] >= k*(1000.0 / cdouble(c_bsize ) ) ) then
        begin
          blocks[i][j][k] := blocks[i][j][k-1];
        end
        else
        begin
          blocks[i][j][k].r := 0.0;
          blocks[i][j][k].g := 0.0;
          blocks[i][j][k].b := 0.0;
          blocks[i][j][k].a := 0.0;
        end;
      end; // for for for
end;


procedure TPIXELMACHINE.generate_objects();
var
  i : cint;

  procedure B(ii, jj, kk: cint; rr,gg,bb,aa: cdouble); inline;
  const SC = 4;
  var
    i2, j2, k2 : cint;
    i,j,k : cint;
  begin
    i2 := ii*SC;
    j2 := jj*SC;
    k2 := kk*SC;
    for i := i2 to pred(i2+SC) do
      for j := j2 to Pred(j2+SC) do
        for k := k2 to Pred(k2+SC) do
        begin
          blocks[i][j][k].r:=rr;
          blocks[i][j][k].g:=gg;
          blocks[i][j][k].b:=bb;
          blocks[i][j][k].a:=aa;
        end;
  end;

begin
  if not ( photons <> 0) then
  begin
    sun[0].x := cdouble(rand() mod 1500) - 250.0;
    sun[0].y := cdouble(rand() mod 1500) - 250.0;
    sun[0].z := cdouble(rand() mod  700) + 100.0;

    cam.x := cdouble(rand() mod 900) + 50.0;
    cam.y := cdouble(rand() mod 900) + 50.0;
    cam.z := terrain[trunc(cam.x/c_sqsize)][trunc(cam.y/c_sqsize)] + cdouble(rand() mod 150) + 50.0;

    tar.x := cdouble(rand() mod 900) + 50.0;
    tar.y := cdouble(rand() mod 900) + 50.0;
    tar.z := cam.z - cdouble(rand() mod 400);

    for i := 0 to Pred(c_spheres) do
    begin
      sphere[i].center.x := cdouble(rand() mod 10000)*0.1;
      sphere[i].center.y := cdouble(rand() mod 10000)*0.1;
      sphere[i].center.z := cdouble(rand() mod 3500)*0.1;
      sphere[i].radius   := cdouble(rand() mod 10000)*0.005;
      sphere[i].color.a  := 1.0;
      sphere[i].color.r  := cdouble(rand() mod 255)/255.0;
      sphere[i].color.g  := cdouble(rand() mod 255)/255.0;
      sphere[i].color.b  := cdouble(rand() mod 255)/255.0;

//      WriteLn('Sphere ',i,' r = ', sphere[i].color.r, ' g = ', sphere[i].color.g, '  = ', sphere[i].color.b);
      DebugLn('Sphere %d : r = %.4f, g = %.4f, b = %.4f', [i, sphere[i].color.r, sphere[i].color.g, sphere[i].color.b]);
    end;
  end
  else
  begin
    cam.x := 728.0;
    cam.y := 621.0;
    cam.z := 631.0;
    tar.x := 625.0;
    tar.y := 625.0;
    tar.z := 604.0;
    sun[0].x := 625.0;
    sun[0].y := 625.0;
    sun[0].z := 749.0;

(*
#   define SC 4
#   define B(ii,jj,kk,rr,gg,bb,aa) {int i2=ii*SC;int j2=jj*SC;int k2=kk*SC;int i,j,k;\
                                   for(i=i2;i<i2+SC;i++) for(j=j2;j<j2+SC;j++) for(k=k2;k<k2+SC;k++)\
                                   { blocks[i][j][k].r=rr; blocks[i][j][k].g=gg; blocks[i][j][k].b=bb; blocks[i][j][k].a=aa;}}
*)
    //space
    B(2,2,2, 0.00,0.00,0.00,0.00);
    B(3,2,2, 0.00,0.00,0.00,0.00);

    //black
    //B(3,2,2, 0.20,0.15,0.10,1.00);
    //main wall
    B(1,2,2, 1.20,1.10,1.00,1.00);
    //floor
    B(2,2,1, 1.20,1.10,1.00,1.00);
    //ceiling
    B(2,2,3, 1.20,1.10,1.00,1.00);
    // right wall
    B(2,3,2, 0.40,0.55,0.35,1.00);
    // left wall
    B(2,1,2, 0.80,0.50,0.30,1.00);

    blocks[8][8][8 ].r := 1.20; blocks[8][8][8 ].g:=1.10; blocks[8][8][8 ].b:=1.00; blocks[8][8][8 ].a:=1.00;
    blocks[8][8][10].r := 1.20; blocks[8][8][10].g:=1.10; blocks[8][8][10].b:=1.00; blocks[8][8][10].a:=1.00;
(*
#   undef B
*)
    sphere[0].center.x := 525.0;
    sphere[0].center.y := 555.0;
    sphere[0].center.z := 584.5;
    sphere[0].radius := 25.0;

    sphere[1].center.x := 540.0;
    sphere[1].center.y := 728.0;
    sphere[1].center.z := 540.0;
    sphere[1].radius := 40.0;

    sphere[2].center.x := 585.0;
    sphere[2].center.y := 584.0;
    sphere[2].center.z := 510.0;
    sphere[2].radius := 10.0;

    sphere[3].center.x := 540.0;
    sphere[3].center.y := 730.0;
    sphere[3].center.z := 620.0;
    sphere[3].radius := 40.0;

    sphere[4].center.x := 585.0;
    sphere[4].center.y := 584.0;
    sphere[4].center.z := 530.0;
    sphere[4].radius := 10.0;

    sphere[5].center.x := 585.0;
    sphere[5].center.y := 584.0;
    sphere[5].center.z := 550.0;
    sphere[5].radius := 10.0;
  end;
end;


procedure TPIXELMACHINE.run();
var
  i,j,k : cint;
  s     : string; // array[0..Pred(80)] of char;
  lin   : TVECTOR;
  t     : cunsigned;
begin
  running := true;

  if ( (PX1-PX0) / cdouble(PATCHDIM) < PHOTONRADIUS )
    then WriteLn( 'WARNING: PATCH SIZE IS SMALLER THAN PHOTON RADIUS!' );

  for i :=0 to Pred(PATCHDIM) do
    for j := 0 to Pred(PATCHDIM) do
      for k := 0 to Pred(PATCHDIM) do
        patch[i][j][k] := nil;

  busy := pcbool(malloc(sizeof(cbool)*threads));


  subtract( lin, tar, cam );
  normalize( lin, 2.0 );


  for i := 0 to Pred(frames) do
  begin
    if not( photons <> 0) then
    begin
      // strcpy(statustext, 'Rendering');
      statustext := 'Rendering';
      render(w,h,false);
      // strcpy(statustext, 'Ready');
      StatusText := 'Ready';
    end
    else
    begin
      // strcpy(statustext,'Photon rendering');
      statustext := 'Photon rendering';
      render_photons(cam,tar,w,h,false);
      // strcpy(statustext,'Ready');
      statustext := 'Ready';
    end;

    WriteLn('Writing frame ', i:4 ,' ...');
    if ( frames > 1 ) then
    begin
      // mkdir('./video');
      if not DirectoryExists('video') then mkdir('video');
      // WriteStr(s, format('./video/frame%.4d.bmp', [i]));
      WriteStr(s, format('video/frame%.4d.bmp', [i]));
      savebmp(PChar(s),w,h);
    end
    else
    begin
      // mkdir('./images');
      if not DirectoryExists('images') then mkdir('images');
      t := cunsigned(chelpers.time(nil));
      // WriteStr(s, format('./images/seed%d_%d.bmp', [seed, t]));
      WriteStr(s, format('images/seed%d_%d.bmp', [seed, t]));
      savebmp(PChar(s),w,h);
    end;

    cam.x := cam.x - (lin.x/2.0);
    cam.y := cam.y - (lin.y/2.0);
    cam.z := cam.z - (lin.z/2.0);
    tar.z := tar.z - 0.50;
    cam.z := cam.z - 0.45;

    for j :=0 to pred(SUNS) do
      sun[j].z := sun[j].z + 0.8;

    for j := 0 to pred(c_spheres) do
    begin
      case ( j mod 3 ) of
        2: sphere[j].center.z := sphere[j].center.z + 1.13;
        1: sphere[j].center.z := sphere[j].center.z - 1.13;
        0: { nothing };
      end;
    end;
  end;

  chelpers.free(busy);
  running := false;
end;


procedure TPIXELMACHINE.savebmp( const _filename: PChar; _w: cint; _h: cint );
var
  i         : cint;
  f         : thandle;
  filesize  : cint;
  bmpfileheader : array[0..Pred(14)] of byte;
  bmpinfoheader : array[0..Pred(40)] of byte;
  bmppad        : array[0..Pred( 3)] of byte;
begin
  filesize := 54 + 3*_w*_h;

  fillbyte(bmpfileheader[0], sizeof(bmpfileheader), 0);
  bmpfileheader[ 0] := ord('B');
  bmpfileheader[ 1] := ord('M');
  bmpfileheader[10] := 54;

  fillbyte(bmpinfoheader[0], sizeof(bmpinfoheader), 0);
  bmpinfoheader[ 0] := 40;
  bmpinfoheader[12] :=  1;
  bmpinfoheader[14] := 24;

  fillbyte(bmppad[0], sizeof(bmppad), 0);

  bmpfileheader[ 2] := byte(filesize       );
  bmpfileheader[ 3] := byte(filesize shr  8);
  bmpfileheader[ 4] := byte(filesize shr 16);
  bmpfileheader[ 5] := byte(filesize shr 24);

  bmpinfoheader[ 4] := byte( _w        );
  bmpinfoheader[ 5] := byte( _w shr  8 );
  bmpinfoheader[ 6] := byte( _w shr 16 );
  bmpinfoheader[ 7] := byte( _w shr 24 );
  bmpinfoheader[ 8] := byte( _h        );
  bmpinfoheader[ 9] := byte( _h shr  8 );
  bmpinfoheader[10] := byte( _h shr 16 );
  bmpinfoheader[11] := byte( _h shr 24 );

  //f = fopen("img.raw","wb");
  //fwrite(img,3,w*h,f);
  //fclose(f);

  f := FileCreate(_filename);
  FileWrite(f, bmpfileheader[0], sizeof(bmpfileheader));
  FileWrite(f, bmpinfoheader[0], sizeof(bmpinfoheader));
  for i := 0 to Pred(_h) do
  begin
    FileWrite(f, img[_w*(_h-i-1)*3], 3 * _w);
    FileWrite(f, bmppad[0], (4-(_w*3) mod 4) mod 4);
  end;
  FileClose(f);
end;


procedure TPIXELMACHINE.render( _w: cint; _h: cint; _quiet: cbool );
var
  i, j  : cint;
  ret   : cint;
  mycam : TVECTOR;
  mytar : TVECTOR;
  kids  : PPSDL_Thread;
  ra    : PRENDER_ARGS;
begin
  mycam := cam;
  mytar := tar;

  kids := PPSDL_Thread(malloc(sizeof(TMyThread)*threads));
  memset(kids,0,sizeof(TMyThread)*threads);

  ra := PRENDER_ARGS(malloc(sizeof(TRENDER_ARGS)*threads));

  if assigned( img )
    then chelpers.free( img );

  img := PByte(malloc(3*_w*_h));
//  memset(img, 0, sizeof(img));

  subtract( mytar, mytar, mycam );
  normalize( mytar, 1.0 );
  add( mytar, mytar, mycam );

  tarw := cdouble(_w)/cdouble(_h)*1.5;
  pixpitch := tarw/cdouble(_w);
  subpitch := pixpitch/(cdouble(multis)+1.0);

  i := 0;
  memset(busy,0,sizeof(cbool)*threads);

  for j := 0 to Pred(_w) do
  begin
    while ( busy[i] ) do // wait for a non-busy thread
    begin
      inc(i);
      if ( i mod threads = 0 ) then
      begin
        Sleep(10);
        i := 0;
      end;
    end;

    if ( cancel )
      then break;

    if assigned( kids[i] ) then
    begin
      Kids[i].WaitFor;
      Kids[i].Free;
      push_region(ra+i);
    end;

    ra[i].cam := mycam;
    ra[i].tar := mytar;
    ra[i].w := _w;
    ra[i].h := _h;
    ra[i].l := _w div 2 + IIF(j mod 2 <> 0, (-j-1) div 2, j div 2 );
    ra[i].r := ra[i].l+1;
    ra[i].t := 0;
    ra[i].b := _h;
    ra[i].quiet := _quiet;
    ra[i].lock := lock;
    ra[i].threadid := i;
    ra[i].pm := self; // this;
    busy[i] := true;
    kids[i] := CreateThread(@ext_render_thread, ra+i);
  end;

  for i :=0 to Pred(threads) do
    if assigned( kids[i] ) then
    begin
      kids[i].WaitFor;
      kids[i].Free;
      push_region(ra+i);
    end;

  chelpers.free(kids);
  chelpers.free(ra);
end;


procedure TPIXELMACHINE.push_region( _ra: PRENDER_ARGS );
var
  i : cint;
begin
  lock.Enter;
  for i := 0 to Pred(reg_count) do // try to smoosh into existing rectangle
  begin
    if
    (
      ( ( (regions[i].r = _ra^.l) or (regions[i].l = _ra^.r) ) and (regions[i].t = _ra^.t) and (regions[i].b = _ra^.b) )
      or
      ( ( (regions[i].b = _ra^.t) or (regions[i].t = _ra^.b) ) and (regions[i].l = _ra^.l) and (regions[i].r = _ra^.r) )
    )
    then
    begin
      regions[i].l := MINVAL(regions[i].l, _ra^.l);
      regions[i].r := MAXVAL(regions[i].r, _ra^.r);
      regions[i].t := MINVAL(regions[i].t, _ra^.t);
      regions[i].b := MAXVAL(regions[i].b, _ra^.b);
      lock.Leave;
      exit;
    end;
  end;

  if ( reg_count = reg_alloc ) then // need to grow?
  begin
    reg_alloc := reg_alloc * 2;
    regions := PREG(realloc(regions, sizeof(TREG)*(reg_alloc)));
  end;
  regions[reg_count].l := _ra^.l;
  regions[reg_count].r := _ra^.r;
  regions[reg_count].t := _ra^.t;
  regions[reg_count].b := _ra^.b;
  inc(reg_count);
  lock.Leave;
end;


function  TPIXELMACHINE.pop_region( _rect: PSDL_RECT ): cbool;
var
  ret: cbool;
begin
  ret := false;

  lock.Enter;
  if ( reg_count > 0 ) then
  begin
    dec(reg_count);
    _rect^.x := regions[reg_count].l;
    _rect^.y := regions[reg_count].t;
    _rect^.w := regions[reg_count].r - regions[reg_count].l;
    _rect^.h := regions[reg_count].b - regions[reg_count].t;
    ret := true;
  end;
  lock.Leave;
  exit( ret );
end;


function  ext_render_thread(data: pointer): cint; cdecl;
var
  ra: TPIXElMACHINE.PRENDER_ARGS absolute data;
begin
  exit( ra^.pm.render_thread( data ) );
end;


function  TPIXELMACHINE.render_thread( _data: pointer ): cint;
var
  i,j,k,m,n : cint;
  di,dj     : cdouble;
  r,g,b     : cdouble;
  {$IFDEF SPILL_GUTS}
  subgoal   : cint;
  {$ENDIF}
  ra        : PRENDER_ARGS;

  color     : PCOLOR;
  lin       : TVECTOR;
  wing      : TVECTOR;
  head      : TVECTOR;
  ray       : TVECTOR;
begin
  ra := PRENDER_ARGS(_data);

  if ( ra^.b > ra^.h ) then ra^.b := ra^.h;
  if ( ra^.b < 0     ) then ra^.b := 0;
  if ( ra^.t > ra^.h ) then ra^.t := ra^.h;
  if ( ra^.t < 0     ) then ra^.t := 0;
  if ( ra^.l > ra^.w ) then ra^.l := ra^.r;
  if ( ra^.l < 0     ) then ra^.l := 0;
  if ( ra^.r > ra^.w ) then ra^.r := ra^.r;
  if ( ra^.r < 0     ) then ra^.r := 0;

  color := PCOLOR(malloc(sizeof(TCOLOR)*(multis*multis)));

  lin.x := ra^.tar.x - ra^.cam.x;
  lin.y := ra^.tar.y - ra^.cam.y;
  lin.z := ra^.tar.z - ra^.cam.z;

  {$IFDEF SPILL_GUTS}
  subgoal := 0;
  {$ENDIF}

  for i := ra^.l to Pred(ra^.r) do
  begin
    for j := ra^.t to Pred(ra^.b) do
    begin
      di := cdouble(i);
      dj := cdouble(j);

      for m := 0 to Pred(multis) do
        for n := 0 to Pred(multis) do
        begin
          k := m + n*multis;

          wing.x :=  lin.y;
          wing.y := -lin.x;
          wing.z := 0.0;

          cross( head, lin, wing );

          normalize( head, (dj- cdouble(ra^.h)/2.0)*pixpitch + subpitch*cdouble(n) );
          normalize( wing, (di- cdouble(ra^.w)/2.0)*pixpitch + subpitch*cdouble(m) );

          ray.x := ra^.tar.x+wing.x+head.x - ra^.cam.x;
          ray.y := ra^.tar.y+wing.y+head.y - ra^.cam.y;
          ray.z := ra^.tar.z+wing.z+head.z - ra^.cam.z;

          raytrace( color[k], ra^.cam, ray, MODE_CAMRAY, 0 );
        end;

      r := 0.0;
      g := 0.0;
      b := 0.0;

      for k := 0 to Pred(multis*multis) do
      begin
        r := r + color[k].r;
        g := g + color[k].g;
        b := b + color[k].b;
      end;

      r := r / cdouble(multis*multis);
      g := g / cdouble(multis*multis);
      b := b / cdouble(multis*multis);

      if ( cancel ) then
      begin
        busy[ra^.threadid] := false;
        exit( 1 );
      end;

      img[(i+j*ra^.w)*3+2] := Byte(trunc(255.0*r+0.5));
      img[(i+j*ra^.w)*3+1] := Byte(trunc(255.0*g+0.5));
      img[(i+j*ra^.w)*3+0] := Byte(trunc(255.0*b+0.5));
    end;
  end;
  FreeMem(color);
  busy[ra^.threadid] := false;
  exit( 1 );
end;


function  ext_photon_thread( data: pointer): cint; cdecl;
var
  pa : TPIXELMACHINE.PPHOTON_ARGS absolute data;
begin
  exit( pa^.pm.photon_thread( data ) );
end;


function  TPIXELMACHINE.photon_thread( _data: pointer ): cint;
var
  pa    : PPHOTON_ARGS;
  i     : cint;
  o     : TVECTOR;
  v     : TVECTOR;
  hrand : pointer;
  th    : cdouble;
  rt1mz2: cdouble;
begin
  pa := PPHOTON_ARGS(_data);

  hrand := sj_srand(pa^.seed);

  for i := 0 to Pred(pa^.ration) do
  begin
    o.x := sun[0].x + sj_rand(hrand)*10.0-20.0;
    o.y := sun[0].y + sj_rand(hrand)*5.0-10.0;
    o.z := sun[0].z;
    // random point on lower hemisphere:
    th := sj_rand(hrand)*3.1415926535897*2.0;
    v.z := -sj_rand(hrand);
    rt1mz2 := sqrt(1.0-v.z*v.z);
    v.y := sin(th)*rt1mz2;
    v.x := cos(th)*rt1mz2;

    raytrace( pa^.c, o, v, MODE_PHOTON, 0);
  end;

  sj_drand(hrand);
  exit( 0 );
end;


procedure TPIXELMACHINE.render_photons( _cam: TVECTOR; _tar: TVECTOR; _w: cint; _h: cint; _quiet: cbool );
var
  i,j,{$IFDEF SPILL_GUTS}k,{$ENDIF}m,n : cint;
  ret       : cint;
  kids      : PPSDl_Thread;
  pa        : PPHOTON_ARGS;
  lin       : TVECTOR;
  di,dj     : cdouble;
  subgoal   : cint;
  {$IFDEF SPILL_GUTS}
  substep   : cint;
  {$ENDIF}
  ration    : cint;
  wing, head, ray   : TVECTOR;
  c         : TCOLOR;
  tn        : cint;
  ii        : cint;
  max       : cdouble;
  scalar    : cdouble;
  ra        : TRENDER_ARGS;
begin
  kids := PPSDL_Thread(malloc(sizeof(PSDL_Thread)*threads));
  memset(kids,0,sizeof(PSDL_Thread)*threads);

  pa := PPHOTON_ARGS(malloc(sizeof(TPHOTON_ARGS)*threads));

  if assigned( img )
    then chelpers.free( img );

  img := PByte(malloc(sizeof(Byte)*3*w*h));
  memset(img,0,sizeof(Byte)*3*w*h);

  dimg := PCOLOR(malloc(sizeof(TCOLOR)*w*h));
  memset(dimg,0,sizeof(TCOLOR)*w*h);

  subtract( _tar, _tar, _cam );
  normalize( _tar, 1.0 );
  add( _tar, _tar, _cam );

  tarw := 2.0;
  pixpitch := tarw/cdouble(_w);
  subpitch := pixpitch/(cdouble(multis)+1.0);

  lin.x := _tar.x - _cam.x;
  lin.y := _tar.y - _cam.y;
  lin.z := _tar.z - _cam.z;

  subgoal := 0;

  // Map screen to world (or is it the other way?)
  for i := 0 to Pred(_w) do
  begin
    for j := 0 to Pred(_h) do
    begin
      di := cdouble(i);
      dj := cdouble(j);

      for m := 0 to pred(multis) do
        for n := 0 to Pred(multis) do
        begin
          {$IFDEF SPILL_GUTS}
          k := m + n*multis;
          {$ENDIF}

          wing.x :=  lin.y;
          wing.y := -lin.x;
          wing.z := 0.0;

          cross( head, lin, wing );

          normalize( wing, (di-cdouble(_w)/2.0)*pixpitch + subpitch*m );
          normalize( head, (dj-cdouble(_h)/2.0)*pixpitch + subpitch*n );

          ray.x := _tar.x+wing.x+head.x - _cam.x;
          ray.y := _tar.y+wing.y+head.y - _cam.y;
          ray.z := _tar.z+wing.z+head.z - _cam.z;

          raytrace( c, _cam, ray, MODE_CAMRAY, 0, j*w+i );
        end;
    end;

    if ( trunc(1000*i/_w) >= subgoal ) then
    begin
      subgoal := subgoal + 20;
      if ( subgoal mod 10 = 0 )
      then WriteStr(statustext, Format('Photon rendering - Mapping screen to world: %d%%', [subgoal/10]));
        // sprintf(statustext,"Photon rendering - Mapping screen to world: %d%%",subgoal/10);
    end;
  end;


  // blast photons around and feed the camera
  ration := (photons*10000) div threads;
  for i := 0 to Pred(100) do
  begin
    for tn := 0 to Pred(threads) do // give each thread a chunk of 1% of all work
    begin
      pa[tn].c.r := 1.0;
      pa[tn].c.g := 1.0;
      pa[tn].c.b := 1.0;
      pa[tn].c.a := 1.0;
      pa[tn].ration := ration;
      pa[tn].seed := seed + i*threads + tn;
      pa[tn].lock := lock;
      pa[tn].threadid := tn;
      pa[tn].pm := self; // this;
      kids[tn] := CreateThread(@ext_photon_thread, pa+tn);
    end;

    for tn :=0 to Pred(threads) do // ; tn++) // wait for all threads
      if assigned( kids[tn] ) then
      begin
        kids[tn].WaitFor;
        kids[tn].Free;
      end;

//    sprintf(statustext,"Photon rendering - Blasting photons: %d%%",i);
    WriteStr(statustext, Format('Photon rendering - Blasting photons: %d%%',[i]));
    if ( cancel )
      then break;

    //if( i==0 || i%10==9 )
    begin
      // adjust dimg vals (HDR-like) and copy to bitmap
      max := 0.0;
      for ii := 0 to pred(w*h) do
      begin
        if ( dimg[i].r > max ) then max := dimg[i].r;
        if ( dimg[i].g > max ) then max := dimg[i].g;
        if ( dimg[i].b > max ) then max := dimg[i].b;
      end;
      scalar := 255.0/max;
      for ii := 0 to pred(w*h) do
      begin
        img[i*3+2] := byte(trunc(dimg[i].r*scalar));
        img[i*3+1] := byte(trunc(dimg[i].g*scalar));
        img[i*3+0] := byte(trunc(dimg[i].b*scalar));
      end;

      // notify main that the image is ready
      ra.l := 0;
      ra.r := w;
      ra.t := 0;
      ra.b := h;
      push_region(@ra);
    end;
  end;

  // sprintf(statustext,"Photon rendering - Done");
  StatusText := 'Photon rendering - Done';

  chelpers.free(kids);
  chelpers.free(pa);
  chelpers.free(dimg);
end;


function  TPIXELMACHINE.raytrace( var _color: TCOLOR; const _cam: TVECTOR; const _ray: TVECTOR; _mode: cint; _bounce : cint; _pixelindex: cint = NO_PIXEL ): TCOLOR;
var
  i,k           : cint;
  r,g,b,a       : cdouble;
  blockx,blocky,
  blockz        : cint;
  hit0,hit1,
  hit2          : TVECTOR;
  hit           : TVECTOR = (x: 0.0; y: 0.0; z: 0.0);
  p0,p1,p2      : cdouble;
  p,potp        : cdouble;
  side          : cint;
  hitobject,
  pothitobject  : cint;
  v             : TVECTOR;
  sidefactor    : cdouble;
  dot, ang      : cdouble;
  c             : PCOLOR;
  beam          : TVECTOR;
  light         : TCOLOR;
  finallight    : TCOLOR;
  m             : cint;
  falloff       : cdouble;
  ray2          : TVECTOR;
  rad           : TVECTOR;
  scatter       : cdouble;
  temp          : TCOLOR;
  diffuseray    : TVECTOR;
begin
  if ( _bounce >= MAXBOUNCE ) then
  begin
    _color.r := 1.0;
    _color.g := 0.0;
    _color.b := 0.0;
    _color.a := 1.0;
    exit(_color);
  end;

  side := XY;

  if ( _mode <> MODE_PHOTON ) then
  begin
    r := 0.0;
    g := 0.0;
    b := 0.0;
    a := 0.0;
  end;


  // spheres
  potp := 99999999.0;
  hitobject := -1;
  pothitobject := -1;
  for i := 0 to Pred(c_spheres) do
  begin
    v := _ray;
    CollideRaySphere(p0, _cam, v, sphere[i].center, sphere[i].radius);

    if ( (p0 <> NO_COLLISION) and (p0+0.00001 < potp) ) then
    begin
      pothitobject := i;
      potp := p0+0.00001;
    end;
  end;


  p := 0.0;
  k := 0;

  while( true ) do
  begin
    // find current space block
    blockx := trunc((_cam.x+p*_ray.x)/blocksize);
    blocky := trunc((_cam.y+p*_ray.y)/blocksize);
    blockz := trunc((_cam.z+p*_ray.z)/blocksize);

    // hit sky
    if ( (blockx<1) or (blockx>c_bsize-1) or (blocky<1) or (blocky>c_bsize-1) or (blockz<0) or (blockz>c_bsize-1)
      or(k>1000) or ( (_mode=MODE_LIGHTTEST) and (p>=1.0) ) ) then
    begin
      if( (_mode=MODE_CAMRAY) and (_pixelindex=NO_PIXEL) ) then
      begin
        dot := (_ray.x*_ray.x + _ray.y*_ray.y);
        ang := abs(dot/( sqrt(dot) * sqrt(_ray.x*_ray.x + _ray.y*_ray.y + _ray.z*_ray.z) ));
        ang := ang * ang;
        r := r + 0.5*ang*(1.0-a);
        g := g + 0.6*ang*(1.0-a);
        b := b + 1.0*ang*(1.0-a);
        a := 1.0;
      end;
      break;
    end;

    inc(k);

    // pickup color from current space block
    if ( hitobject>=0 )
    then c := @sphere[hitobject].color
    else c := @blocks[blockx][blocky][blockz];

    if ( (k>1) and ( (c^.a>0.0) or (hitobject>=0) ) ) then
    begin
      if ( (_mode <> MODE_PHOTON) and (_pixelindex=NO_PIXEL) ) then // NOT photoning, NOT building a reverse photon map
      begin
        if ( _mode = MODE_LIGHTTEST ) then
        begin
          _color.r := 0.0;
          _color.g := 0.0;
          _color.b := 0.0;
          _color.a := 0.7;
          exit( _color );
        end;

        // get incoming light/shadow

        finallight.r := 0.0;
        finallight.g := 0.0;
        finallight.b := 0.0;

        for m := 0 to Pred(SUNS) do
        begin
          subtract( beam, sun[m], hit );
          raytrace( light, hit, beam, MODE_LIGHTTEST, 0 );

          falloff := c_falloff/(beam.x*beam.x + beam.y*beam.y + beam.z*beam.z);
          light.r := light.r*0.0+(1.0-light.a)*falloff;
          light.g := light.g*0.0+(1.0-light.a)*falloff;
          light.b := light.b*0.0+(1.0-light.a)*falloff;

          finallight.r := finallight.r + light.r;
          finallight.g := finallight.g + light.g;
          finallight.b := finallight.b + light.b;
        end;

        finallight.r := finallight.r / cdouble(SUNS);
        finallight.g := finallight.g / cdouble(SUNS);
        finallight.b := finallight.b / cdouble(SUNS);

        sidefactor := IIF(side=XY, 1.0, IIF(side=XZ, 0.9,0.8));
      end;

      if ( (blockz=0) or (hitobject>=0) or
          not(photons <> 0) and (blockx>(c_bsize*2)/5) and (blockx<(c_bsize*3)/5)
                            and (blocky>(c_bsize*2)/5) and (blocky<(c_bsize*3)/5) ) then //reflect!
      begin
        if ( (_mode <> MODE_PHOTON) and (_pixelindex=NO_PIXEL) ) then
        begin
          finallight.r := finallight.r + (0.7*(1.0-finallight.r));
          finallight.g := finallight.g + (0.7*(1.0-finallight.g));
          finallight.b := finallight.b + (0.7*(1.0-finallight.b));
        end;

        ray2 := _ray;

        if ( hitobject>=0 ) then
        begin
          subtract( rad, hit, sphere[hitobject].center );

          ray2 := _ray;
          normalize(rad, 2.0*(_ray.x*rad.x+_ray.y*rad.y+_ray.z*rad.z)/sphere[hitobject].radius );
          subtract(ray2,_ray, rad);
        end
        else
        if ( side=XY )
        then ray2.z := -_ray.z
        else
        if ( side=XZ )
        then ray2.y := -_ray.y
        else ray2.x := -_ray.x;

        if not( photons <> 0 ) then
        begin
          if ( hitobject>=0 ) then
          begin
            scatter := 0.0;
            ray2.x := ray2.x * (1.0 + cdouble(rand() mod 1000)*scatter);
            ray2.y := ray2.y * (1.0 + cdouble(rand() mod 1000)*scatter);
            ray2.z := ray2.z * (1.0 + cdouble(rand() mod 1000)*scatter);
          end
          else
          begin
            scatter := SCATTER_VAL;
            ray2.x := ray2.x * (1.0 + cdouble(rand() mod 1000)*scatter + sin(hit.x)*0.1);
            ray2.y := ray2.y * (1.0 + cdouble(rand() mod 1000)*scatter + sin(hit.y)*0.1);
            ray2.z := ray2.z * (1.0 + cdouble(rand() mod 1000)*scatter);
          end;
        end;

        raytrace(_color, hit, ray2, _mode, _bounce+1, _pixelindex);

        if ( (_mode <> MODE_PHOTON) and (_pixelindex=NO_PIXEL) ) then
        begin
          r := r + _color.r*(1.0-a)*sidefactor*finallight.r;
          g := g + _color.g*(1.0-a)*sidefactor*finallight.g;
          b := b + _color.b*(1.0-a)*sidefactor*finallight.b;
          a := 1.0;
        end;

        break;
      end;

      if ( _pixelindex <> NO_PIXEL ) then // building pixel map, attach and stop
      begin
        attach( _pixelindex, hit );
        exit( _color );
      end;

      if ( _mode=MODE_PHOTON ) then
      begin
        temp.r := c^.r*_color.r;
        temp.g := c^.g*_color.g;
        temp.b := c^.b*_color.b;

        feed(temp, hit);

        //INDIRECT/DIFFUSE BOUNCE HERE:
        if ( rand() mod 2 =0 ) then
        begin
          diffuseray.x := cdouble(rand()*INVRAND)-1.0;
          diffuseray.y := cdouble(rand()*INVRAND)-1.0;
          diffuseray.z := cdouble(rand()*INVRAND)-1.0;

          //temp.r *= 10.0;
          //temp.g *= 10.0;
          //temp.b *= 10.0;

          if ( diffuseray.x*_ray.x + diffuseray.y*_ray.y + diffuseray.z*_ray.z > 0.0 ) then
          begin
            diffuseray.x := -diffuseray.x;
            diffuseray.y := -diffuseray.y;
            diffuseray.z := -diffuseray.z;
          end;
          raytrace(temp, hit, diffuseray, MODE_PHOTON, _bounce+1);
        end;
        break;
      end;


      r := r + c^.r*c^.a*(1.0-a)*sidefactor*finallight.r;
      g := g + c^.g*c^.a*(1.0-a)*sidefactor*finallight.g;
      b := b + c^.b*c^.a*(1.0-a)*sidefactor*finallight.b;
      a := a + (c^.a*(1.0-a));

      if ( a>=0.98 ) then
      begin
        a := 1.0;
        break;
      end;
    end;

    // move to next space block
    hit0.x := cdouble(blockx*blocksize) + (IIF(_ray.x>0.0, blocksize,0.0));
    hit1.y := cdouble(blocky*blocksize) + (IIF(_ray.y>0.0, blocksize,0.0));
    hit2.z := cdouble(blockz*blocksize) + (IIF(_ray.z>0.0, blocksize,0.0));

    p0 := (hit0.x-_cam.x)/(_ray.x) + 0.00001;
    p1 := (hit1.y-_cam.y)/(_ray.y) + 0.00001;
    p2 := (hit2.z-_cam.z)/(_ray.z) + 0.00001;

    if ( (trunc((cam.x+p0*_ray.x)/blocksize)=blockx) and ( trunc((cam.y+p0*_ray.y)/blocksize)=blocky) and ( trunc((cam.z+p0*_ray.z)/blocksize)=blockz) )
    then p0 := 99999.0;
    if ( (trunc((cam.x+p1*_ray.x)/blocksize)=blockx) and ( trunc((cam.y+p1*_ray.y)/blocksize)=blocky) and ( trunc((cam.z+p1*_ray.z)/blocksize)=blockz) )
    then p1 := 99999.0;
    if ( (trunc((cam.x+p2*_ray.x)/blocksize)=blockx) and ( trunc((cam.y+p2*_ray.y)/blocksize)=blocky) and ( trunc((cam.z+p2*_ray.z)/blocksize)=blockz) )
    then p2 := 99999.0;

    if ( (p0<p) or (p1<p) or (p2<p) )
      then break;

    if ( (p0<p1) and (p0<p2) ) then
    begin
      side := YZ;
      p := p0;
    end
    else if ( p1<p2 ) then
    begin
      side := XZ;
      p := p1;
    end
    else
    begin
      side := XY;
      p := p2;
    end;

    if ( (spheremania and (blockz>0)) and (blocks[blockx][blocky][blockz-1].a>0.0) ) then // crazy speheres!!
    begin
      sphere[c_spheres].center.x := cdouble(blockx+0.5)*c_sqsize;
      sphere[c_spheres].center.y := cdouble(blocky+0.5)*c_sqsize;
      sphere[c_spheres].center.z := cdouble(blockz+0.5)*c_sqsize;
      sphere[c_spheres].radius := c_sqsize*0.4;
      sphere[c_spheres].color.r := 1.0;
      sphere[c_spheres].color.g := 1.0;
      sphere[c_spheres].color.b := 1.0;
      sphere[c_spheres].color.a := 1.0;
      CollideRaySphere(p0, cam, _ray, sphere[c_spheres].center, sphere[c_spheres].radius);

      if ( (p0<>NO_COLLISION) and (p0+0.00001 < p) ) then
      begin
        hitobject := c_spheres;
        side := XY;
        p := p0+0.00001;
      end;
    end;

    if ( p>potp ) then
    begin
      hitobject := pothitobject;
      side := XY;
      p := potp;
    end;

    hit.x := (p-0.00002)*_ray.x + _cam.x;
    hit.y := (p-0.00002)*_ray.y + _cam.y;
    hit.z := (p-0.00002)*_ray.z + _cam.z;
  end;

  if ( _mode <> MODE_PHOTON ) then
  begin
    if ( r>1.0 ) then r := 1.0;
    if ( g>1.0 ) then g := 1.0;
    if ( b>1.0 ) then b := 1.0;
    if ( r<0.0 ) then r := 0.0;
    if ( g<0.0 ) then g := 0.0;
    if ( b<0.0 ) then b := 0.0;

    _color.r := r;
    _color.g := g;
    _color.b := b;
    _color.a := a;
  end;

  exit( _color );
end;


// attach()
//
// attaches a screen pixel to a patch cube, so that the
// screen pixel can be found by photons later on
//
procedure TPIXELMACHINE.attach( _pixelindex: cint; const _hit : TVECTOR);
var
  dx,dy,dz: cdouble;
  x,y,z : cint;
  P     : ^PPatch;
begin
  dx := cdouble(PATCHDIM)/(PX1-PX0);
  dy := cdouble(PATCHDIM)/(PY1-PY0);
  dz := cdouble(PATCHDIM)/(PZ1-PZ0);

  if ( (_hit.x<=PX0) or (_hit.x>=PX1) or (_hit.y<=PY0) or (_hit.y>=PY1) or (_hit.z<=PZ0) or (_hit.z>=PZ1) ) // not indexible
    then exit;

  x := trunc((_hit.x-PX0)*dx);
  y := trunc((_hit.y-PY0)*dy);
  z := trunc((_hit.z-PZ0)*dz);

  p := @patch[x][y][z];
  while assigned( p^ ) do
    p := @((p^)^.n);

  p^ := PPatch(malloc(sizeof(TPATCH)));
  (p^)^.v := _hit;
  (p^)^.i := _pixelindex;
  (p^)^.n := nil;

  tempx := x;
  tempy := y;
  tempz := z;

  exit;
end;


// feed()
//
// finds local screens pixels to a photon collision and adds
// light to those pixels
//
procedure TPIXELMACHINE.feed( const _c: TCOLOR; const _hit: TVECTOR );
var
  dx,dy,dz: cdouble;
  i,j,k : cint;
  pixel : cint;
  m,n,o,dsq : cdouble;
  x,y,z : cint;
  P : PPATCH;
begin
  dx := cdouble(PATCHDIM)/(PX1-PX0);
  dy := cdouble(PATCHDIM)/(PY1-PY0);
  dz := cdouble(PATCHDIM)/(PZ1-PZ0);

  if ( (_hit.x<=PX0) or (_hit.x>=PX1) or (_hit.y<=PY0) or (_hit.y>=PY1) or (_hit.z<=PZ0) or (_hit.z>=PZ1) ) // not indexible
    then exit;

  x := trunc((_hit.x-PX0)*dx);
  y := trunc((_hit.y-PY0)*dy);
  z := trunc((_hit.z-PZ0)*dz);

  for i := x-1 to x+1 do
    for j := y-1 to y+1 do
      for k := z-1 to z+1 do
      begin
        if ( (i<0) or (i>PATCHDIM-1) or (j<0) or (j>PATCHDIM-1) or (k<0) or (k>PATCHDIM-1) )
        then continue;
        p := patch[i][j][k];
        while assigned(p) do
        begin
          // test for proximity!
          m := p^.v.x-_hit.x;
          n := p^.v.y-_hit.y;
          o := p^.v.z-_hit.z;
          dsq := m*m+n*n+o*o;
          if ( dsq <= PHOTONRADIUS ) then
          begin
            pixel := p^.i;
            dimg[pixel].r := dimg[pixel].r + (_c.r*(PHOTONRADIUS*1.5-dsq));
            dimg[pixel].g := dimg[pixel].g + (_c.g*(PHOTONRADIUS*1.5-dsq));
            dimg[pixel].b := dimg[pixel].b + (_c.b*(PHOTONRADIUS*1.5-dsq));
          end;
          p := p^.n;
        end;
      end; // for for for
  exit;
end;

end.
