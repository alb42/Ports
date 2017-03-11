unit sjui;

{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  ctypes, font, SDL;

const
  SJUIF_EXTENDSV   = $1;
  SJUIF_EXTENDSH   = $2;
  SJUIF_STRETCHFIT = $4;

type
  SJUI_HANDLE       = cint;

  PPSJUI_CONTROL = ^PSJUI_CONTROL;
  PSJUI_CONTROL = ^TSJUI_CONTROL;
  TSJUI_CONTROL = record
    handle      : SJUI_HANDLE;
    parent      : PSJUI_CONTROL;
    children    : PPSJUI_CONTROL;
    pos         : TSDL_Rect;
    child_count : cint;
    child_alloc : cint;
    caption     : PChar;
    visible     : cbool;
    interactive : cbool;
    flags       : cint;
    procedure   init();
    procedure   destroy();
  end;

  PSJUI = ^TSJUI;
  TSJUI = record
    handle_max      : cint;
    root            : TSJUI_CONTROL;
    shortcuts       : PPSJUI_CONTROL;
    shortcut_count  : cint;
    shortcut_alloc  : cint;
    modal           : SJUI_HANDLE;

    procedure init();
    procedure destroy();
    
    procedure paint( screen: PSDL_Surface );
    procedure focus( handle: SJUI_HANDLE; _modal: cbool );
    procedure check_in();
    function  mouse_to(x: cint; y: cint): cbool;
    function  mouse_down(button: cint): cbool;
    function  mouse_up(button: cint): cbool;
    function  key_down(key: cint): cbool;
    function  key_up(key: cint): cbool;

    procedure set_pos(handle: SJUI_HANDLE; x: cint; y: cint);
    procedure set_size(handle: SJUI_HANDLE; w: cint; h: cint);
    procedure set_caption(handle: SJUI_HANDLE; const s: PChar);

    function  new_control(parent: SJUI_HANDLE; w: cint; h: cint; flags: cint): SJUI_HANDLE;
    function  new_menu(parent: SJUI_HANDLE): SJUI_HANDLE;
    function  get_by_handle(handle: SJUI_HANDLE): PSJUI_CONTROL;
  end;


implementation


uses
  chelpers;


procedure DrawSquare( surf: PSDL_Surface; rect: PSDL_Rect; color: Uint32 );
var
  edge: TSDL_Rect;
begin
  edge := rect^;
  edge.w := 1;
  SDL_FillRect(surf, @edge, color);
  edge.x := edge.x + (rect^.w - 1);
  SDL_FillRect(surf, @edge, color);
  edge := rect^;
  edge.h := 1;
  SDL_FillRect(surf, @edge, color);
  edge.y := edge.y + (rect^.h - 1);
  SDL_FillRect(surf, @edge, color);
end;


procedure TSJUI_CONTROL.Init;
begin
  handle := 0;
  parent := nil;
  pos.x := 0;
  pos.y := 0;
  pos.w := 0;
  pos.h := 0;
  child_count := 0;
  child_alloc := 8;
  children := PPSJUI_CONTROL(malloc(sizeof(PSJUI_CONTROL)*child_alloc));
  caption := nil;
  visible := true;
  interactive := true;
  flags := 0;
end;


procedure TSJUI_CONTROL.Destroy;
var
  i: cint;
begin
  for i := 0 to Pred(child_count) do
  begin
    children[i]^.destroy();
    free( children[i] );
  end;
  free(children);

  if assigned( caption )
    then free(caption);
end;


procedure TSJUI.init;
begin
  root.init();
  handle_max := 1;
  shortcut_count := 1;
  shortcut_alloc := 8;
  shortcuts := PPSJUI_CONTROL(malloc(sizeof(PSJUI_CONTROL)*shortcut_alloc));
  shortcuts[0] := @root;
  modal := 0;
end;


procedure TSJUI.Destroy;
begin
  free(shortcuts);
  root.destroy();
end;


procedure TSJUI.paint( screen: PSDL_Surface );
var
  i         : cint;
  visible   : cbool;
  rect      : TSDL_Rect;
  p, q      : PSJUI_CONTROL;
begin
  for i :=0 to Pred(shortcut_count) do
  begin
    p := shortcuts[i];
    visible := p^.visible;
    rect := p^.pos;

    q := p;
    while assigned( q^.parent ) do
    begin
      q := q^.parent;
      rect.x := rect.x + q^.pos.x;
      rect.y := rect.y + q^.pos.y;
      if not( q^.visible )
        then visible := false;
    end;

    if ( visible ) then
    begin
      SDL_FillRect(screen, @rect, $000000);
      DrawSquare(screen, @rect, $3333FF);
      if assigned( p^.caption )
        then SJF_DrawText(screen, rect.x+2, rect.y+2, p^.caption);
    end;
  end;
end;


procedure TSJUI.focus( handle: SJUI_HANDLE; _modal: cbool );
begin
  // blank
end;

procedure TSJUI.check_in();
begin
end;


function  TSJUI.mouse_to(x: cint; y: cint): cbool;
begin
end;


function  TSJUI.mouse_down(button: cint): cbool;
begin
end;


function  TSJUI.mouse_up(button: cint): cbool;
begin
end;


function  TSJUI.key_down(key: cint): cbool;
begin
end;


function  TSJUI.key_up(key: cint): cbool;
begin
end;


procedure TSJUI.set_pos(handle: SJUI_HANDLE; x: cint; y: cint);
var
  p : PSJUI_CONTROL;
begin
  p := get_by_handle(handle);
  p^.pos.x := x;
  p^.pos.y := y;
end;


procedure TSJUI.set_size(handle: SJUI_HANDLE; w: cint; h: cint);
var
  p : PSJUI_CONTROL;
begin
  p := get_by_handle(handle);
  p^.pos.w := w;
  p^.pos.h := h;
end;


procedure TSJUI.set_caption(handle: SJUI_HANDLE; const s: PChar);
var
  p : PSJUI_CONTROL;
begin
  p := get_by_handle(handle);
  p^.caption := PChar(realloc(p^.caption, strlen(s)+1));
  strcpy(p^.caption, s);
end;


function  TSJUI.new_control(parent: SJUI_HANDLE; w: cint; h: cint; flags: cint): SJUI_HANDLE;
var
  i : cint;
  p : PSJUI_CONTROL;
  q : PSJUI_CONTROL;
  max, temp : cint;
begin
  p := get_by_handle(parent);

  if ( p^.child_count >= p^.child_alloc ) then
  begin
    // p^.children := PPSJUI_CONTROL(realloc( p^.children, sizeof(PSJUI_CONTROL)*(p^.child_alloc*=2) ) );
    p^.children := PPSJUI_CONTROL(realloc( p^.children, sizeof(PSJUI_CONTROL)*(p^.child_alloc) ) );
    p^.child_alloc := p^.child_alloc * 2;
  end;
  p^.children[p^.child_count] := PSJUI_CONTROL(malloc(sizeof(TSJUI_CONTROL)));
  q := p^.children[p^.child_count];
  inc(p^.child_count);

  q^.init();
  q^.parent := p;
  q^.flags := flags;
  q^.handle := handle_max; inc(handle_max);
  q^.pos.w := w;
  q^.pos.h := h;
  if ( shortcut_count >= shortcut_alloc ) then
  begin
    // shortcuts := PPSJUI_CONTROL(realloc( shortcuts, sizeof(PSJUI_CONTROL)*(shortcut_alloc*=2) ) );
    shortcuts := PPSJUI_CONTROL(realloc( shortcuts, sizeof(PSJUI_CONTROL)*(shortcut_alloc) ) );
    shortcut_alloc := shortcut_alloc * 2;
  end;
  shortcuts[shortcut_count] := q; inc(shortcut_count);

  if ( flags and SJUIF_EXTENDSV <> 0) then
  begin
    max := 0;
    for i := 0 to pred(p^.child_count) do 
    begin
      temp := p^.children[i]^.pos.y + p^.children[i]^.pos.h;
      if ( temp > max )
        then max := temp;
    end;
    q^.pos.y := max;
  end;

  if ( ( flags and SJUIF_EXTENDSV <> 0 ) or ( flags and SJUIF_EXTENDSH <> 0 ) ) then
  begin
    if ( p^.pos.h < q^.pos.y+q^.pos.h )
      then p^.pos.h := q^.pos.y+q^.pos.h;
    if ( p^.pos.w < q^.pos.x+q^.pos.w )
      then p^.pos.w := q^.pos.x+q^.pos.w;
  end;

  exit( q^.handle);
end;


function  TSJUI.new_menu(parent: SJUI_HANDLE): SJUI_HANDLE;
begin
  exit( 0 );
end;


function  TSJUI.get_by_handle(handle: SJUI_HANDLE): PSJUI_CONTROL;
var
  i : cint;
begin
  for i := 0 to pred(shortcut_count) do
    if ( shortcuts[i]^.handle = handle )
      then exit( shortcuts[i] );
  exit(@root);
end;


end.
