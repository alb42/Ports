unit font;

{$MODE OBJFPC}{$H+}

interface

uses
  ctypes, SDL;


  procedure SJF_Init(const pinfo: PSDL_VideoInfo);
  procedure SJF_DrawChar(surf: PSDL_Surface; x: cint; y: cint; c: char);
  procedure SJF_DrawText(surf: PSDL_Surface; x: cint; y: cint; s: PChar);
  procedure SDL_SetPixel(surf: PSDL_Surface; x: cint; y: cint; R: Uint8; G: Uint8; B: Uint8);

implementation


var
  gpofont       : PSDL_Surface;

  gnfontw       : cint = 8;
  gnfonth       : cint = 12;
  gnfontpitch   : cint = 128;
  gnfontspace   : array[0..pred(256)] of cint =
  (
    6,3,5,7,7,6,7,3,5,5,6,7,3,6,3,6,
    6,6,6,6,6,6,6,6,6,6,3,3,5,6,5,7,
    7,6,6,6,6,6,6,6,6,5,6,6,6,7,7,6,
    6,6,6,6,7,6,7,7,7,7,6,5,6,5,7,7,
    4,6,6,6,6,6,5,6,6,4,5,6,4,7,6,6,
    6,6,5,6,5,6,7,7,7,6,6,5,3,5,6,6,
    6,7,9,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,

    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  );

  gsfontraw     : ansistring =
  (
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '         O       O O               O                     O         O     O                                                  O   ' +
    '         O       O O      O O     OOO             OO     O        O       O      O  O      O                                O   ' +
    '         O               OOOOO   O O             O  O            O         O      OO       O                               O    ' +
    '         O                O O     OOO    O  O     OO             O         O      OO     OOOOO           OOOO              O    ' +
    '         O                O O      O O     O     O  OO           O         O     O  O      O                              O     ' +
    '                         OOOOO    OOO     O      O  O             O       O                O                              O     ' +
    '         O                O O      O     O  O     OO O             O     O                       O               O       O      ' +
    '                                                                                                 O                       O      ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                          OOO   ' +
    '  OO       O      OO      OO       OO    OOOO     OO     OOOO     OO      OO                       O             O       O   O  ' +
    ' O  O     OO     O  O    O  O     O O    O       O          O    O  O    O  O                     O      OOOO     O          O  ' +
    ' O OO      O        O      O     O  O    OOO     OOO       O      OO     O  O    O       O       O                 O        O   ' +
    ' OO O      O      OO        O    OOOO       O    O  O      O     O  O     OOO                     O      OOOO     O        O    ' +
    ' O  O      O     O       O  O       O    O  O    O  O     O      O  O       O                      O             O              ' +
    '  OO      OOO    OOOO     OO        O     OO      OO      O       OO      OO     O       O                                 O    ' +
    '                                                                                         O                                      ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '  OOO     OO     OOO      OO     OOO     OOOO    OOOO     OO     O  O    OOO       OO    O  O    O       O   O   O   O    OO    ' +
    ' O   O   O  O    O  O    O  O    O  O    O       O       O  O    O  O     O         O    O  O    O       OO OO   OO  O   O  O   ' +
    ' O OOO   O  O    O  O    O       O  O    O       O       O       O  O     O         O    O O     O       O O O   O O O   O  O   ' +
    ' O O O   OOOO    OOO     O       O  O    OOO     OOO     O OO    OOOO     O         O    OO      O       O O O   O  OO   O  O   ' +
    ' O OOO   O  O    O  O    O       O  O    O       O       O  O    O  O     O         O    O O     O       O   O   O   O   O  O   ' +
    ' O       O  O    O  O    O  O    O  O    O       O       O  O    O  O     O      O  O    O  O    O       O   O   O   O   O  O   ' +
    '  OOO    O  O    OOO      OO     OOO     OOOO    O        OOO    O  O    OOO      OO     O  O    OOOO    O   O   O   O    OO    ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    ' OOO      OO     OOO      OOO    OOOOO   O  O    O   O   O   O   O   O   O   O   OOOO    OOO     O       OOO       O            ' +
    ' O  O    O  O    O  O    O         O     O  O    O   O   O   O   O   O   O   O      O    O       O         O      O O           ' +
    ' O  O    O  O    O  O    O         O     O  O    O   O   O   O    O O    O   O     O     O        O        O     O   O          ' +
    ' OOO     O  O    OOO      OO       O     O  O    O   O   O O O     O      OOO     O      O        O        O                    ' +
    ' O       O  O    O O        O      O     O  O     O O    O O O    O O      O     O       O         O       O                    ' +
    ' O       O  O    O  O       O      O     O  O     O O    O O O   O   O     O     O       O         O       O                    ' +
    ' O        OO     O  O    OOO       O      OO       O      O O    O   O     O     OOOO    OOO        O    OOO                    ' +
    '            O                                                                                       O                    OOOOO  ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    ' O               O                  O              O             O        O        O     O       OO                             ' +
    '  O              O                  O             O              O                       O        O                             ' +
    '          OO     OOO      OOO     OOO     OO     OOO      OOO    OOO     OO       OO     O  O     O      OOOO    OOO      OO    ' +
    '         O  O    O  O    O       O  O    O  O     O      O  O    O  O     O        O     O O      O      O O O   O  O    O  O   ' +
    '          OOO    O  O    O       O  O    OOOO     O      O  O    O  O     O        O     OO       O      O O O   O  O    O  O   ' +
    '         O  O    O  O    O       O  O    O        O      O  O    O  O     O        O     O O      O      O O O   O  O    O  O   ' +
    '          OOO    OOO      OOO     OOO     OOO     O       OOO    O  O     O        O     O  O     O      O O O   O  O     OO    ' +
    '                                                            O                      O                                            ' +
    '                                                          OO                     OO                                             ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                           O     O       O        O O           ' +
    '                                  O                                                       O      O        O      O O            ' +
    ' OOO      OOO    O O      OOO    OOO     O  O    O   O   O O O   O   O   O  O    OOOO     O      O        O                     ' +
    ' O  O    O  O    OO      O        O      O  O    O   O   O O O    O O    O  O       O    O       O         O                    ' +
    ' O  O    O  O    O        OO      O      O  O     O O    O O O     O     O  O     OO      O               O                     ' +
    ' O  O    O  O    O          O     O      O  O     O O    O O O    O O    O  O    O        O      O        O                     ' +
    ' OOO      OOO    O       OOO      OO      OOO      O      OOOO   O   O    OOO    OOOO      O     O       O                      ' +
    ' O          O                                                               O                    O                              ' +
    ' O          O                                                             OO                     O                              ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '           O        OOO                                                                                                         ' +
    '           OO       OOOO         OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    '         O  O        OOO         O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO    OO      OOO             O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO     O O    OOOO OOO        O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO       OO    OOO OOOO       O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO     O  O         OOO       O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    '          OO       OOO           OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    '           O       OOOO                                                                                                         ' +
    '                    OOO                                                                                                         ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O    O  O   ' +
    ' OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO    OOOO   ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                ' +
    '                                                                                                                                '
  );


procedure SJF_Init(const pinfo: PSDL_VideoInfo);
var
  u, v: cint;
begin
  WriteLn('enter - SJF_Init');
//  WriteLn('gsfontraw[0] = "', gsfontraw[1], '"');

  gpofont := SDL_CreateRGBSurface(SDL_SRCCOLORKEY, 128, 128, pinfo^.vfmt^.BitsPerPixel, pinfo^.vfmt^.Rmask, pinfo^.vfmt^.Gmask, pinfo^.vfmt^.Bmask, pinfo^.vfmt^.Amask);
  SDL_SetColorKey( gpofont, SDL_SRCCOLORKEY, SDL_MapRGB(gpofont^.format,0,0,0) );
  SDL_FillRect( gpofont, nil, SDL_MapRGB(gpofont^.format,0,0,0) );
  SDL_LockSurface( gpofont );
  for u := 0 to Pred(128) do
    for v := 0 to Pred(128) do
      if (gsfontraw[Succ(u+v*128)] <> ' ' )
        then SDL_SetPixel( gpofont, u, v, 255, 255, 255 )
        else 
          if
          ( 
            ( (u < 127) and (gsfontraw[succ((u+1)+(v+0)*128)] <> ' ') ) and
            ( (u >   0) and (gsfontraw[succ((u-1)+(v+0)*128)] <> ' ') ) and
            ( (v < 127) and (gsfontraw[succ((u+0)+(v+1)*128)] <> ' ') ) and
            ( (v >   0) and (gsfontraw[succ((u+0)+(v-1)*128)] <> ' ') )
          ) 
          then SDL_SetPixel( gpofont, u, v, 0, 0, 1 ); 
  SDL_UnlockSurface( gpofont );
end;


procedure SJF_DrawChar(surf: PSDL_Surface; x: cint; y: cint; c: char);
var
  src   : TSDL_Rect;
  dst   : TSDL_Rect;
begin
  src.x := ( ord(c)     mod 16)*gnfontw;
  src.y := ((ord(c)-32) div 16)*gnfonth;
  src.w := 8;
  src.h := 12;

  dst.x := x;
  dst.y := y;
  dst.w := 8;
  dst.h := 12;

  SDL_UpperBlit(gpofont, @src, surf, @dst);
end;


procedure SJF_DrawText(surf: PSDL_Surface; x: cint; y: cint; s: PChar);
var
  src   : TSDL_Rect;
  dst   : TSDL_Rect;
begin
  src.h := 12;
  dst.x := x;
  dst.y := y;
  dst.h := 12;

  while ( s^ <> #0 ) do
  begin
    src.x := ( ord(s^)     mod 16)*gnfontw;
    src.y := ((ord(s^)-32) div 16)*gnfonth;
    src.w := gnfontspace[PUint8(s)^-32]-1;
    dst.w := src.w;
    SDL_UpperBlit(gpofont, @src, surf, @dst);
    dst.x := dst.x + src.w;
    inc(s);
  end;
end;


procedure SDL_SetPixel(surf: PSDL_Surface; x: cint; y: cint; R: Uint8; G: Uint8; B: Uint8);
var
  color     : Uint32;
  bufp8     : PUint8;
  bufp16    : PUint16;
  bufp32    : PUint32;
begin
  color := SDL_MapRGB(surf^.format, R, G, B);
  case (surf^.format^.BytesPerPixel) of
    1: // 8-bpp
    begin
       bufp8  := PUint8(surf^.pixels) + y*surf^.pitch + x;
       bufp8^ := color;
    end;

    2: // 15-bpp or 16-bpp
    begin
      bufp16  := PUint16(surf^.pixels) + y*surf^.pitch div 2 + x;
      bufp16^ := color;
    end;

    3: // 24-bpp mode, usually not used
    begin
      bufp8 := PUint8(surf^.pixels) + y*surf^.pitch + x * 3;
      if (SDL_BYTEORDER = SDL_LIL_ENDIAN) then
      begin
        bufp8[0] := color;
        bufp8[1] := color shr 8;
        bufp8[2] := color shr 16;
      end
      else
      begin
        bufp8[2] := color;
        bufp8[1] := color shr 8;
        bufp8[0] := color shr 16;
      end;
    end;

    4: // 32-bpp
    begin
      bufp32  := PUint32(surf^.pixels) + y*surf^.pitch div 4 + x;
      bufp32^ := color;
    end;
  end;
end;

end.
