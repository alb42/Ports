program pixelmachine;

{*
** PixelMachine
** v 0.2.20071108
**
** A ray-traced 3D renderer by SuperJer
**
** Email = superjer@superjer.com
** Web   = http://www.superjer.com/
**
**
**
*}

// converted to pascal by magorium, march 2017.
// see also https://github.com/superjer/pixelmachine

{$MODE OBJFPC}{$H+}
{.$DEFINE SPILL_GUTS}

uses
  {$ifdef Linux}
  cthreads,
  {$endif}
  //heaptrc,
  {$ifdef AROS}
  AThreads,
  arosc_static_link,
  {$endif}
  Classes,
  math, simpledebug,
  ctypes, chelpers, sysutils,
  pixelina, sjui, font,
  SDL;

const
  Width         = 800;
  Height        = 600;

  NO_MULTIS     = 2;
  {$ifdef AROS}
  NO_THREADS    = 2;   // 8;
  {$else}
  NO_THREADS    = 8;   // 8;
  {$endif}
  NO_PHOTONS    = 0;

var
  gutime        : UInt32 = 0;
  gutimenow     : UInt32 = 0;

  sdlrender     : PSDL_Surface = nil;
  sdlscreen     : PSDL_Surface = nil;
  thread        : TMyThread;

  pinfo         : PSDL_VideoInfo;
  pixelmachina  : TPIXELMACHINE;

  ui            : TSJUI;
  h_menu,
  h_render      : SJUI_HANDLE;


function run_pixel_machine( data : pointer ): cint; cdecl;
begin
  pixelmachina.run();
  exit( 0 );
end;


procedure Render();
var
  i,j,m,n   : cint;
  info      : PSDL_VideoInfo;
  rect      : TSDL_Rect;

  {$IFDEF SPILL_GUTS}
  color     : Uint32;
  {$ENDIF}
  winw      : cint;
  winh      : cint;
  ratiox    : cdouble;
  ratioy    : cdouble;
  
  r,g,b     : Uint8;
begin
  info := SDL_GetVideoInfo();
  if not assigned(info) then
  DebugLn('SDL_GetVideoInfo() returned an invalid structure');
  winw := info^.current_w;
  winh := info^.current_h;

  if assigned( sdlrender ) then
  begin
    if not ( SDL_LockSurface(sdlrender) <> 0) then
    begin
      while ( pixelmachina.pop_region(@rect) ) do
      begin
        for i := rect.x to Pred(rect.x + rect.w) do 
        begin
          for j := rect.y to Pred(rect.y + rect.h) do
          begin
            b := pixelmachina.img[(i+j*pixelmachina.w)*3+0];
            g := pixelmachina.img[(i+j*pixelmachina.w)*3+1];
            r := pixelmachina.img[(i+j*pixelmachina.w)*3+2];
            ratiox := cdouble(winw)/cdouble(pixelmachina.w);
            ratioy := cdouble(winh)/cdouble(pixelmachina.h);

            for m := trunc(i*ratiox) to Pred(trunc((i+1)*ratiox)) do
              for n := trunc(j*ratioy) to Pred(trunc((j+1)*ratioy)) do
              begin
                SDL_SetPixel(sdlrender, m, n, r, g, b);
              end;
          end;  
        end;
      end;
      SDL_UnlockSurface(sdlrender);
    end;
    SDL_BlitSurface(sdlrender, nil, sdlscreen, nil);
  end;

  ui.set_caption(h_render, PChar(pixelmachina.statustext));
  ui.paint(sdlscreen);
  SDL_Flip(sdlscreen);
end;



procedure SetVideo( nw: cint; nh : cint );
var
  different: cbool;
begin
  DebugLn('enter - SetVideo(%d,%d) ', [nw, nh]);
  different := ( not assigned(pinfo) or (nw <> pinfo^.current_w) or (nh <> pinfo^.current_h) );

  sdlscreen := SDL_SetVideoMode( nw, nh, SDL_GetVideoInfo()^.vfmt^.BitsPerPixel, SDL_RESIZABLE or SDL_DOUBLEBUF );
  pinfo := SDL_GetVideoInfo();

  DebugLn('pinfo^.vfmt^.BitsPerPixel  = %d', [pinfo^.vfmt^.BitsPerPixel ]);
  DebugLn('pinfo^.vfmt^.BytesPerPixel = %d', [pinfo^.vfmt^.BytesPerPixel]);

  if ( different and assigned(sdlrender) )
    then SDL_FreeSurface(sdlrender);

  if ( different )
    then sdlrender := SDL_CreateRGBSurface(0, nw, nh, pinfo^.vfmt^.BitsPerPixel, pinfo^.vfmt^.Rmask, pinfo^.vfmt^.Gmask, pinfo^.vfmt^.Bmask, pinfo^.vfmt^.Amask);
end;


function InRect( const porect: PSDL_Rect; const nx: cint; const ny: cint ): boolean;
begin
  exit
  ( 
    ( nx >= porect^.x ) and 
    ( nx < (porect^.x + porect^.w) ) and
    ( ny >= porect^.y ) and 
    ( ny < (porect^.y + porect^.h) )
  );
end;


procedure Cleanup();
begin
  ui.destroy();
  SDL_Quit();
end;


function PixelMachine_Main(argc: cint; argv: PpChar): cint;
var
  event     : TSDL_Event;
  {$IFDEF SPILL_GUTS}
  u         : Uint32;
  v         : Uint32;
  {$ENDIF}
  i         : cint;
  w         : cint;
  h         : cint;
  multis    : cint;
  threads   : cint;
  photons   : cint;
  seed      : cunsigned;
  preview   : cbool;
  
  stupid_var_parameter_declaration_for_thread_status: cint;
begin
  DebugLn('enter - PixelMachine_Main()');

  w := Width;
  h := Height;

  multis := NO_MULTIS;
  threads := NO_THREADS;
  photons := NO_PHOTONS;
  seed := cunsigned(-1);
  preview := true;

//  NICEME;

  DebugLn('handling arguments');

  // Process cmd line args
  for i := 1 to Pred(argc) do
  begin
    if (argv[i][0]='-' ) then 
      case ( argv[i][1] ) of
        'w': w := atoi(argv[i]+2);
        'h': h := atoi(argv[i]+2);
        'm': multis := atoi(argv[i]+2);
        't': threads := atoi(argv[i]+2);
        'p': photons := atoi(argv[i]+2);
        '-': 
        begin
          // printf( 'Usage: [OPTION]... [SEED]\nRender ray-traced 3D images generated randomly with seed number SEED.\n\n  option default description\n  -wNUM  %7d Set image output width to NUM\n  -hNUM  %7d Set image output height to NUM\n  -mNUM  %7d Set multisampling level to NUM (level 2 recommended)\n  -tNUM  %7d Parallelize with NUM threads\n  -pNUM  %7d Simulate lighting with NUM million photons!\n',W,H,MULTIS,THREADS,PHOTONS ), 
          WriteLn( 'Usage: [OPTION]... [SEED]');
          WriteLn( 'Render ray-traced 3D images generated randomly with seed number SEED.');
          WriteLn;
          WriteLn( '  option default description');
          WriteLn( '  -wNUM  ', W:7          ,' Set image output width to NUM');
          WriteLn( '  -hNUM  ', H:7          ,' Set image output height to NUM');
          WriteLn( '  -mNUM  ', NO_MULTIS:7  ,' Set multisampling level to NUM (level 2 recommended)');
          WriteLn( '  -tNUM  ', NO_THREADS:7 ,' Parallelize with NUM threads');
          WriteLn( '  -pNUM  ', NO_PHOTONS:7 ,' Simulate lighting with NUM million photons!');
          exit(0);
        end;
        else 
        begin
          WriteLn( stderr, 'Halt! -', argv[i][1], ' isn''t one of my options!');
          WriteLn( 'Use --help for help.');
          exit(-1);
        end;
      end
    else 
    if ( seed=cunsigned(-1) ) then
    begin
      seed := atoi(argv[i]);
      if not ( seed <> 0 ) then 
      begin
        WriteLn( stderr, 'Halt! SEED ought to be a positive number, not ', argv[i] );
        exit(-1);
      end;
    end
    else
    begin
      WriteLn( stderr, 'Halt! I''m confused by cmd line argument #', i, ': ', argv[i] );
      exit(-1);
    end;
  end;

  DebugLn('arguments done');

  if ( w < 1 ) then w := Width;
  if ( h < 1 ) then h := Height;
  if ( multis  < 1 ) then multis  := NO_MULTIS;
  if ( threads < 1 ) then threads := NO_THREADS;
  if ( photons < 1 ) then photons := NO_PHOTONS;

  DebugLn('checking seed');

  // Use time as seed if not otherwise specified
  if ( seed = cunsigned(-1) ) then
  begin
    DebugLn('inside seed checking');
    seed := cunsigned(chelpers.time(nil) );
  end;

  DebugLn('the seed used for this trace = %d', [seed]);

  // Init SDL
  DebugLn('init sdl');
  if ( ( SDL_Init(SDL_INIT_TIMER or SDL_INIT_AUDIO or SDL_INIT_VIDEO ) < 0) or not( SDL_GetVideoInfo() <> nil) )
    then exit( 0 );

  // Create Window
  DebugLn('Set video');

  SetVideo( w, h );
  SDL_WM_SetCaption('PixelMachine', nil);

  DebugLn('Call: SDL_GetVideoInfo()');

  pinfo := SDL_GetVideoInfo();

  // font init
  DebugLn('Call: SJF_Init(pinfo)');
  SJF_Init(pinfo);

  // ui setup
  DebugLn('Call: ui.init()');
  ui.init();
  h_menu   := ui.new_control(0,0,0,0);
  h_render := ui.new_control(h_menu,80,15,SJUIF_EXTENDSV);
  ui.set_caption(h_menu, 'Click to render...');
  ui.set_caption(h_render, 'Loading');

  // pm preview render setup
  pixelmachina := TPIXELMACHINE.Create; // new PIXELMACHINE;
  pixelmachina.init(seed, 100, 75, 1, threads, IIF(photons <> 0, 1,0));
  thread := CreateThread(@run_pixel_machine, nil);  // another stupidity declaration... a PInt ... really ????

  // MAIN LOOP
  while ( true ) do
  begin
    while ( SDL_PollEvent(@event) <> 0) do
    begin
      case (event.type_) of
        SDL_VIDEOEXPOSE: { nothing } ;
        SDL_VIDEORESIZE: 
        begin
          DebugLn('Resize');
          SetVideo( event.resize.w, event.resize.h );
        end;
        SDL_MOUSEBUTTONDOWN:
        begin
          if ( preview ) then
          begin
            // pm full render go!
            preview := false;
            pixelmachina.cancel := true;
            //WaitThread(thread, stupid_var_parameter_declaration_for_thread_status); //BUG: thread may not be valid?
            Thread.WaitFor;
            Thread.Free;
            pixelmachina.Free; // delete pixelmachine;
            pixelmachina := TPIXELMACHINE.Create; // new PIXELMACHINE;
            pixelmachina.init(seed, w, h, multis, threads, photons);
            thread := CreateThread(@run_pixel_machine, nil); // another stupidity declaration... a PInt ... really ????
          end;
        end;
        SDL_KEYDOWN: { nothing } ;
        SDL_QUITEV:
        begin
          pixelmachina.cancel := true;
          //SDL_WaitThread(thread, stupid_var_parameter_declaration_for_thread_status); //BUG: thread may not be valid?
          Thread.WaitFor;
          Thread.Free;
          pixelmachina.Free;
          Cleanup();
          exit(0);
        end;
      end;
    end;

    gutimenow := SDL_GetTicks();
    if ( Uint32(gutimenow-gutime) > 50 ) then
    begin
      Render();
      gutime := gutimenow;
    end;

    // chill out for a bit
    SDL_Delay(10);
  end;

  exit( 0 );
end;


procedure PixelMachine_Startup;
begin
  // needed the exceptionmask in order to get at least something running
  // in order to be able to pinpoint what the culprits were :-)
  // SetExceptionMask(GetExceptionMask+[ExZeroDivide,exInvalidOp]);
  ExitCode := PixelMachine_Main(ArgC, ArgV);
end;



begin
  {$IFDEF AROS}
  AROSC_Init(@PixelMachine_Startup);
  {$ELSE}
  PixelMachine_Startup;
  {$ENDIF}
end.
