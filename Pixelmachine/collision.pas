unit collision;

{*
** collision.h
**
** Some nice vector functions and stuff... for PixelMachine
** by SuperJer
**
** Email = superjer@superjer.com
** Web   = http://www.superjer.com/
**
** You can do whatever you like with this code, I don't care,
** just please recognize me as the original author. :)
**
*}

interface

uses
  ctypes;

const
  NO_COLLISION = -1.0;


type
  PVECTOR = ^TVECTOR;
  TVECTOR =
  record
    x : cdouble;
    y : cdouble;
    z : cdouble;
  end;

  PPPCOLOR = ^PPCOLOR;
  PPCOLOR = ^PCOLOR;
  PCOLOR = ^TCOLOR;
  TCOLOR =
  record
    r : cdouble;
    g : cdouble;
    b : cdouble;
    a : cdouble;
  end;

  PSPHERE = ^TSPHERE;
  TSPHERE =
  record
    center  : TVECTOR;
    radius  : cdouble;
    color   : TCOLOR;
  end;


  function  add( var ov: TVECTOR; const av: TVECTOR; const bv: TVECTOR ): TVECTOR;
  function  subtract( var ov: TVECTOR; const av: TVECTOR; const bv : TVECTOR ): TVECTOR;
  function  cross( var ov: TVECTOR; const av: TVECTOR; const bv: TVECTOR ): TVECTOR;
  function  scale( var ov: TVECTOR; n: cdouble ): TVECTOR;
  function  normalize( var ov: TVECTOR; n: cdouble ): TVECTOR;
  function  mirror( var ov: TVECTOR; const iv: TVECTOR; const mv: TVECTOR ): TVECTOR;
  procedure CollideRaySphere( var t: cdouble; const ov: TVECTOR; const vv: TVECTOR; const pv: TVECTOR; const r: cdouble );


implementation


function  add( var ov: TVECTOR; const av: TVECTOR; const bv: TVECTOR ): TVECTOR;
begin
  ov.x := av.x + bv.x;
  ov.y := av.y + bv.y;
  ov.z := av.z + bv.z;
  exit( ov );
end;


function  subtract( var ov: TVECTOR; const av: TVECTOR; const bv : TVECTOR ): TVECTOR;
begin
  ov.x := av.x - bv.x;
  ov.y := av.y - bv.y;
  ov.z := av.z - bv.z;
  exit( ov );
end;


function  cross( var ov: TVECTOR; const av: TVECTOR; const bv: TVECTOR ): TVECTOR;
begin
  ov.x := av.y*bv.z - av.z*bv.y;
  ov.y := av.z*bv.x - av.x*bv.z;
  ov.z := av.x*bv.y - av.y*bv.x;
  exit( ov );
end;


function  scale( var ov: TVECTOR; n: cdouble ): TVECTOR;
begin
  ov.x := ov.x * n;
  ov.y := ov.y * n;
  ov.z := ov.z * n;
  exit( ov );
end;


function  normalize( var ov: TVECTOR; n: cdouble ): TVECTOR;
var
  l: cdouble;
begin
  l := sqrt(ov.x*ov.x + ov.y*ov.y + ov.z*ov.z);
  ov.x := ov.x * (n/l);
  ov.y := ov.y * (n/l);
  ov.z := ov.z * (n/l);
  exit( ov );
end;


function  mirror( var ov: TVECTOR; const iv: TVECTOR; const mv: TVECTOR ): TVECTOR;
var
  perp1, 
  perp2     : TVECTOR;

  a,b,c, 
  x,y,z, 
  i,j,k     : cdouble;
  m,n       : cdouble;
  v1, v2    : TVECTOR;
begin
  cross( perp1, iv, mv );
  cross( perp2, perp1, mv );
    
  a := mv.x;
  b := perp2.x;
  c := iv.x;
  
  x := mv.y;
  y := perp2.y;
  z := iv.y;
  
  i := mv.z;
  j := perp2.z;
  k := iv.z;
    
  if ( (a > -0.0001) and (a < 0.0001) ) then
  begin
    if ( (i > -0.0001) and (i < 0.0001) ) then
    begin
      ov.x := -iv.x;
      ov.y :=  iv.y;
      ov.z := -iv.z;
      exit( ov );
    end
    else
    begin
      n := (z - (x*k)/i)/(y - (x*j)/i);
      m := (k - (j*n))/i;
    end;
  end
  else
  begin
    n := (z - (x*c)/a)/(y - (x*b)/a);
    m := (c - (b*n))/a;
  end;

  v1 := mv;
  v2 := perp2;

  scale( v1, m );
  scale( v2, n );

  subtract( ov, v1, v2 );
  exit( ov );
end;

// This function is part of the SPARToR game engine by SuperJer.com
procedure CollideRaySphere( var t: cdouble; const ov: TVECTOR; const vv: TVECTOR; const pv: TVECTOR; const r: cdouble );
var
  a, b, c, d, ox, oy, oz: cdouble;
begin
  // check that v is even headed toward the sphere first
  begin
    if
    ( 
      ( (vv.x>0.0) and (ov.x>pv.x+r) ) or ( (vv.x<0.0) and (ov.x<pv.x-r) ) or
      ( (vv.y>0.0) and (ov.y>pv.y+r) ) or ( (vv.y<0.0) and (ov.y<pv.y-r) ) or 
      ( (vv.z>0.0) and (ov.z>pv.z+r) ) or ( (vv.z<0.0) and (ov.z<pv.z-r) ) 
    ) then
    begin
      t := NO_COLLISION;
      exit;
    end;
  end;

  // quadratic formula
  ox := ov.x - pv.x;
  oy := ov.y - pv.y;
  oz := ov.z - pv.z;
  a := 2.0*(vv.x*vv.x + vv.y*vv.y + vv.z*vv.z);
  b := 2.0*(vv.x*ox   + vv.y*oy   + vv.z*oz  );
  c := ox*ox + oy*oy + oz*oz - r*r;

  d := b*b - 2.0*a*c; // determinant
  if ( d < 0.0 ) then // no intersection at all
  begin
    t := NO_COLLISION;
    exit;
  end;
  a := 1.0 / a;
  d := sqrt( d );
  t := (-d - b) * a;
  if ( t >= 0.0 ) then exit; // smaller root wins
  t := ( d - b) * a;
  if ( t >= 0.0 ) then exit; // bigger root wins
  t := NO_COLLISION;
  exit; // no root in range
end;


end.
