program Game;
{$MODE OBJFPC}

uses
  SDL, SysUtils,
{$ifdef AROS}
  arosc_static_link, icon,
{$endif}
   FGL, Math;

type
  TThing = class
  public
    X, Y: Integer;
    OX, OY: Single;
    Img: PSDL_Surface;
  end;

  PEnemy = ^TEnemy;
  TEnemy = class(TThing)
  public
    TOX, TOY: Single;
    Direction: Integer;
  end;

  TProjectile = class(TThing)
  public
    FX, FY, DX, DY: Single;
    PHarm, EHarm: Boolean;
    Life: Integer;
  end;

  TThingList = specialize TFPGObjectList<TThing>;
  TEnemyList = TThingList;//specialize TFPGObjectList<TEnemy>;
  TProjectileList = TThingList;//specialize TFPGObjectList<TProjectile>;

var
  Surface, RealSurface: PSDL_Surface;
  Running: Boolean = True;
  KeyState: array [0..1024] of Boolean;
  Background, LifeImg, PlayerImg, PlayerHitImg, PlayerDeadImg, PlayerShootImg,
    RetryImg, Nums, PBulletImg, EBulletImg, Enemy1Img, Enemy2Img, P1Img, P2Img: PSDL_Surface;
  PlayerX: Integer;
  Enemies: TEnemyList;
  Projectiles: TProjectileList;
  Level, Life, Score, RetryY: Integer;
  ToDelete: array of TObject;
  PlayerShootTime, ShootTime, HitTime: Cardinal;
  ScaleMode: Integer = 1;

function SDL_SoftStretch(Src: PSDL_Surface; SrcRect: PSDL_Rect; Dst: PSDL_Surface; DstRect: PSDL_Rect): Integer; cdecl; external;// 'SDL';

function RectOverRect(AX1, AY1, AX2, AY2, BX1, BY1, BX2, BY2: Integer): Boolean; inline;
begin
  Result:=not ((BX1 > AX2) or (BX2 < AX1) or (BY1 > AY2) or (BY2 < AY1));
end;

function CollisionWithEnemy(CX, CY: Integer; CW: Integer=32; CH: Integer=32; Ignore: Integer=-1; Enemy: PEnemy=nil): Boolean;
var
  I: Integer;
begin
  for I:=0 to Enemies.Count - 1 do with Enemies[I] do
    if (I <> Ignore) and RectOverRect(X, Y, X + 31, Y + 31, CX, CY, CX + CW - 1, CY + CH - 1) then begin
      if Assigned(Enemy) then Enemy^:=TEnemy(Enemies[I]);
      Exit(True);
    end;
  Result:=False;
end;

procedure LaunchProjectile(X, Y, DX, DY: Single; Img: PSDL_Surface; PHarm, EHarm: Boolean; Life: Integer=-1);
var
  P: TProjectile;
begin
  P:=TProjectile.Create;
  Projectiles.Add(P);
  P.X:=Round(X);
  P.Y:=Round(Y);
  P.FX:=X;
  P.FY:=Y;
  P.DX:=DX;
  P.DY:=DY;
  P.Img:=Img;
  P.PHarm:=PHarm;
  P.EHarm:=EHarm;
  P.Life:=Life;
end;

procedure DeleteLater(AObject: TObject);
var
  I: Integer;
begin
  for I:=0 to High(ToDelete) do if ToDelete[I]=AObject then Exit;
  SetLength(ToDelete, Length(ToDelete) + 1);
  ToDelete[High(ToDelete)]:=AObject;
end;

procedure DeleteDeferredObjects;
var
  I: Integer;
begin
  for I:=0 to High(ToDelete) do begin
    if ToDelete[I] is TProjectile then Projectiles.Remove(TProjectile(ToDelete[I]))
    else if ToDelete[I] is TEnemy then Enemies.Remove(TEnemy(ToDelete[I]))
    else ToDelete[I].Free;
  end;
  SetLength(ToDelete, 0);
end;

function Key(K: Integer): Boolean; inline;
begin
  if (K >= Low(KeyState)) and (K <= High(KeyState)) then Result:=KeyState[K] else Result:=False;
end;

function InitVideo: Boolean;
var
  Flags: Cardinal = SDL_DOUBLEBUF or SDL_SWSURFACE;
  I: Integer;
  Bits: Integer = 16;
  {$ifdef AROS}
  ToolTypes: TToolTypeArray;
  {$endif}
begin
  for I:=1 to ParamCount do begin
    if ParamStr(I)='-fullscreen' then begin
      Flags:=Flags + SDL_FULLSCREEN;
      SDL_ShowCursor(0);
    end;
    if ParamStr(I)='-double' then ScaleMode:=2;
    if ParamStr(I)='-triple' then ScaleMode:=3;
    if ParamStr(I)='-8bit' then Bits:=8;
  end;
  {$ifdef AROS}
  ToolTypes := GetToolTypes(ParamStr(0));
  for i := 0 to High(ToolTypes) do
  begin
    if LowerCase(Trim(ToolTypes[i]))='fullscreen' then begin
      Flags:=Flags + SDL_FULLSCREEN;
      SDL_ShowCursor(0);
    end;
    if LowerCase(Trim(ToolTypes[i]))='double' then ScaleMode:=2;
    if LowerCase(Trim(ToolTypes[i]))='triple' then ScaleMode:=3;
    if LowerCase(Trim(ToolTypes[i]))='8bit' then Bits:=8;
  end;
  {$endif}
  if ScaleMode > 1 then begin
    RealSurface:=SDL_SetVideoMode(320*ScaleMode, 240*ScaleMode, 16, Flags);
    with RealSurface^.format^ do
      Surface:=SDL_CreateRGBSurface(SDL_SWSURFACE, 320, 240, 16, Rmask, Gmask, Bmask, Amask);
  end else begin
    Surface:=SDL_SetVideoMode(320, 240, Bits, Flags);
    RealSurface:=Surface;
  end;
  Result:=Assigned(Surface);
end;

procedure ShowSurface;
var
  S, D: TSDL_Rect;
begin
  if ScaleMode > 1 then begin
    S.x:=0;
    S.y:=0;
    S.w:=320;
    S.h:=240;
    D.x:=0;
    D.y:=0;
    D.w:=320*ScaleMode;
    D.h:=240*ScaleMode;
    SDL_SoftStretch(Surface, @S, RealSurface, @D);
  end;
  SDL_Flip(RealSurface);
end;

procedure LoadImages;

  function Load(Name: AnsiString): PSDL_Surface;
  begin
    Result:=SDL_LoadBMP(PChar(Name));
    SDL_SetColorKey(Result, SDL_SRCCOLORKEY, SDL_MapRGB(Result^.format, 255, 0, 255));
  end;

begin
  Background:=SDL_LoadBMP('bgnd.bmp');
  Nums:=Load('nums.bmp');
  PlayerImg:=Load('player.bmp');
  PlayerHitImg:=Load('plrhit.bmp');
  PlayerDeadImg:=Load('plrdead.bmp');
  PlayerShootImg:=Load('plrshoot.bmp');
  RetryImg:=Load('retry.bmp');
  LifeImg:=Load('life.bmp');
  PBulletImg:=Load('pbullet.bmp');
  EBulletImg:=Load('ebullet.bmp');
  Enemy1Img:=Load('enemy1.bmp');
  Enemy2Img:=Load('enemy2.bmp');
  P1Img:=Load('part1.bmp');
  P2Img:=Load('part2.bmp');
end;

procedure TitleScreen;
var
  Title: PSDL_Surface;
  Ev: TSDL_Event;
  ShowTitle: Boolean = True;
begin
  Title:=SDL_LoadBMP('title.bmp');
  while ShowTitle do begin
    while SDL_PollEvent(@Ev) <> 0 do begin
      case Ev.Type_ of
        SDL_QUITEV: begin
          Running:=False;
          ShowTitle:=False;
        end;
        SDL_KEYDOWN: case Ev.Key.KeySym.Sym of
          SDLK_ESCAPE: begin
            Running:=False;
            ShowTitle:=False;
          end;
          SDLK_Space: ShowTitle:=False;
        end;
      end;
    end;
    SDL_BlitSurface(Title, nil, Surface, nil);
    ShowSurface;
  end;
end;

procedure DrawScreen;

  procedure Draw(X, Y: Integer; Surf: PSDL_Surface);
  var
    R: TSDL_Rect;
  begin
    R.x:=X;
    R.y:=Y;
    R.w:=Surf^.w;
    R.h:=Surf^.h;
    SDL_BlitSurface(Surf, nil, Surface, @R);
  end;

  procedure DrawNum(X, Y, N: Integer);
  var
    R, S: TSDL_Rect;
  begin
    R.x:=X;
    R.y:=Y;
    R.w:=8;
    R.h:=10;
    S.x:=N*8;
    S.y:=0;
    S.w:=8;
    S.h:=10;
    SDL_BlitSurface(Nums, @S, Surface, @R);
  end;

  procedure DrawNumber(X, Y, N: Integer);
  var
    V: Integer = 10000000;
  begin
    repeat
      if (N div V > 0) or (N=0) then begin
        DrawNum(X, Y, (N div V) mod 10);
        Inc(X, 8);
      end;
      V:=V div 10;
    until (V=0) or (N=0);
  end;

  procedure DrawThings(ThingList: TThingList);
  var
    I: Integer;
  begin
    for I:=0 to ThingList.Count - 1 do with ThingList[I] do
      Draw(Round(X + OX), Round(Y + OY), Img);
  end;

  procedure DrawHUD;
  var
    I: Integer;
  begin
    for I:=0 to Life - 1 do Draw(I*6 + 1, 14, LifeImg);
    DrawNumber(1, 1, Score);
    if Life=0 then Draw(40, RetryY, RetryImg);
  end;

begin
  Draw(0, 0, Background);
  if Life > 0 then begin
    if HitTime=0 then
      if ShootTime=0 then
        Draw(PlayerX, 206, PlayerImg)
      else
        Draw(PlayerX, 206, PlayerShootImg)
    else
      Draw(PlayerX, 206, PlayerHitImg);
  end else
    Draw(PlayerX, 206, PlayerDeadImg);
  DrawThings(Enemies);
  DrawThings(Projectiles);
  DrawHUD;

  ShowSurface;
end;

procedure NewGame(Reset: Boolean);

  procedure InitEnemies;
  var
    GX, GY: Integer;
  begin
    for GY:=0 to 3 do
      for GX:=0 to 7 do begin
        Enemies.Add(TEnemy.Create);
        with TEnemy(Enemies[GY*8 + GX]) do begin
          X:=GX*32 + 32;
          Y:=GY*32;
          Direction:=1;
          if (Level*17 + GX*311 + GY*3787) mod 2=0 then
            Img:=Enemy1Img
          else
            Img:=Enemy2Img;
        end;
      end;
    if Level < 19 then
      for GX:=1 to 19-Level do Enemies.Remove(Enemies[Random(Enemies.Count)]);
  end;

begin
  PlayerX:=160 - 16;
  if Reset then begin
    Life:=4;
    Level:=1;
    Score:=0;
  end;
  FreeAndNil(Enemies);
  FreeAndNil(Projectiles);
  Enemies:=TEnemyList.Create;
  Projectiles:=TProjectileList.Create;
  InitEnemies;
end;

procedure UpdateGame;

  procedure LaunchPoof(X, Y: Integer; Img: PSDL_Surface; Life: Integer);
  begin
    LaunchProjectile(X, Y, -1, -0.4, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, -0.2, -0.7, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, 0.3, -0.6, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, 0.96, -0.3, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, -0.8, 0.5, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, -0.3, 0.65, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, 0.34, 0.67, Img, False, False, Life+Random(10));
    LaunchProjectile(X, Y, 0.93, 0.31, Img, False, False, Life+Random(10));
  end;

  procedure MovePlayer(D: Integer);
  begin
    if (PlayerX + D < 0) or (PlayerX + D > 320-32) then Exit;
    PlayerX:=PlayerX + D;
  end;

  procedure MoveEnemies;
  var
    I, J: Integer;
    Collisions: Boolean;
    Sides: array of Integer;
  begin
    for I:=0 to Enemies.Count - 1 do with TEnemy(Enemies[I]) do begin
      Inc(X, Direction);
      OX:=OX + (TOX - OX)*0.9;
      OY:=OY + (TOY - OY)*0.9;
      TOX:=TOX*0.9;
      TOY:=TOY*0.9;
      if (Game.Life <> 0) and RectOverRect(X, Y, X + 31, Y + 31, PlayerX, 206, PlayerX + 31, 240) then begin
        DeleteLater(Enemies[I]);
        LaunchPoof(X, Y, P2Img, 10);
        LaunchPoof((X + PlayerX) div 2, (Y + 206) div 2, P2Img, 30);
        LaunchPoof(PlayerX + 13, 204, P1Img, 70);
        LaunchPoof(PlayerX + 17, 207, P1Img, 96);
        Game.Life:=0;
        RetryY:=-32;
      end;
    end;
    SetLength(Sides, 0);
    repeat
      Collisions:=False;
      for I:=0 to Enemies.Count - 1 do with TEnemy(Enemies[I]) do
        if (X <= 0) or (X >= 320-32) or CollisionWithEnemy(X, Y, 32, 32, I) then begin
          if (X <= 0) or (X >= 320-32) then begin
            SetLength(Sides, Length(Sides) + 1);
            Sides[High(Sides)]:=Y;
          end;
          Direction:=-Direction;
          Inc(X, Direction);
          Collisions:=True;
        end;
    until not Collisions;
    for I:=0 to Enemies.Count - 1 do with Enemies[I] do
      for J:=0 to High(Sides) do
        if Sides[J] <= Y then begin
          Inc(Y, 2);
          Break;
        end;
  end;

  procedure Splash(CX, CY: Integer);
  const
    Radius = 100;
  var
    I: Integer;
    Len, TX, TY: Single;
  begin
    for I:=0 to Enemies.Count - 1 do with TEnemy(Enemies[I]) do begin
      TX:=X - CX + 16;
      TY:=Y - CY + 16;
      Len:=Sqrt(Sqr(TX) + Sqr(TY));
      if Len=0 then TX:=0 else TX:=TX/Len * 10;
      if Len=0 then TY:=0 else TY:=TY/Len * 10;
      TOX:=TOX + Max(0, Radius - Len)/Radius * TX;
      TOY:=TOY + Max(0, Radius - Len)/Radius * TY;
    end;
  end;

  procedure MoveProjectiles;
  var
    I: Integer;
    Enemy: TEnemy;
  begin
    for I:=0 to Projectiles.Count - 1 do with TProjectile(Projectiles[I]) do begin
      FX:=FX + DX;
      FY:=FY + DY;
      X:=Round(FX);
      Y:=Round(FY);
      if Life <> -1 then Dec(Life);
      if (X < -9) or (Y < -9) or (X > 320) or (Y > 230) or (Life=0) then begin
        if PHarm and (Y > 230) then begin
          LaunchProjectile(X, Y - 4, 0.3, -0.6, P1Img, False, False, 10+Random(10));
          LaunchProjectile(X, Y - 4, -0.5, -0.5, P1Img, False, False, 12+Random(10));
        end;
        DeleteLater(Projectiles[I]);
        Continue;
      end;
      if EHarm and CollisionWithEnemy(X, Y, 9, 9, -1, @Enemy) then begin
        DeleteLater(Projectiles[I]);
        DeleteLater(Enemy);
        LaunchPoof(Enemy.X + 16, Enemy.Y + 16, P1Img, 20);
        Splash(Enemy.X + 16, Enemy.Y + 16);
        Inc(Score, Y*3+30);
        Continue;
      end;
      if PHarm and (Game.Life > 0) and RectOverRect(X, Y, X + 8, Y + 8, PlayerX + 4, 210, PlayerX + 28, 224) then begin
        DeleteLater(Projectiles[I]);
        HitTime:=4;
        LaunchPoof(X, Y, P2Img, 10);
        Dec(Game.Life);
        if Game.Life=0 then begin
          LaunchPoof((X + PlayerX) div 2, (Y + 206) div 2, P2Img, 30);
          LaunchPoof(PlayerX + 13, 204, P1Img, 70);
          LaunchPoof(PlayerX + 17, 207, P1Img, 96);
          RetryY:=-32;
        end;
        Continue;
      end;
    end;
  end;

  procedure ShootPlayerBullet;
  begin
    if SDL_GetTicks - PlayerShootTime < (200 - Min(100, Max(0, Level*4))) then Exit;
    PlayerShootTime:=SDL_GetTicks;
    ShootTime:=4;
    LaunchProjectile(PlayerX + 11, 204, 0, -4, PBulletImg, False, True);
  end;

  procedure ShootEnemyBullet;
  var
    TX, TY, Len: Single;
  begin
    if Random(100) > 4*((Level div 3)+1)  then Exit;
    if Enemies.Count=0 then Exit;
    with TEnemy(Enemies[Random(Enemies.Count)]) do begin
      TOY:=TOY-2;
      TX:=PlayerX - X;
      TY:=206 - Y;
      Len:=Sqrt(TX*TX + TY*TY);
      TX:=TX/Len;
      TY:=TY/Len;
      LaunchProjectile(X + 12, Y + 30, TX, TY, EBulletImg, True, False);
    end;
  end;

begin
  if Life > 0 then begin
    if Key(SDLK_LEFT) then MovePlayer(-4)
    else if Key(SDLK_RIGHT) then MovePlayer(4);
    if Key(SDLK_LCTRL) then ShootPlayerBullet;

    if Enemies.Count=0 then begin
      SDL_Delay(600);
      Inc(Life);
      Inc(Score, 1000);
      Inc(Level);
      NewGame(False);
    end;
  end else begin
    if RetryY < 100 then Inc(RetryY, 6);
    if Key(SDLK_LCTRL) then begin
      NewGame(True);
      SDL_Delay(500);
      Exit;
    end;
  end;
  MoveEnemies;
  MoveProjectiles;
  ShootEnemyBullet;
  if HitTime > 0 then Dec(HitTime);
  if ShootTime > 0 then Dec(ShootTime);
end;

procedure MainLoop;
var
  LastTime, CurrentTime: Cardinal;

  procedure HandleEvents;
  var
    Ev: TSDL_Event;

    procedure HandleKey(Sym: Integer; Down: Boolean);
    begin
      if (Sym >= Low(KeyState)) and (Sym <= High(KeyState)) then KeyState[Sym]:=Down;
      case Sym of
        SDLK_ESCAPE: Running:=False;
      end;
    end;

  begin
    while SDL_PollEvent(@Ev) <> 0 do begin
      case Ev.Type_ of
        SDL_QUITEV: Running:=False;
        SDL_KEYDOWN: HandleKey(Ev.Key.KeySym.Sym, True);
        SDL_KEYUP: HandleKey(Ev.Key.KeySym.Sym, False);
      end;
    end;
  end;

begin
  LastTime:=SDL_GetTicks();
  while Running do begin
    CurrentTime:=SDL_GetTicks();
    if CurrentTime - LastTime > 1000 then LastTime:=CurrentTime - 60;
    while CurrentTime - LastTime > 1000/20 do begin
      UpdateGame;
      Inc(LastTime, 20);
    end;
    HandleEvents;
    DrawScreen;
    DeleteDeferredObjects;
  end;
end;

procedure GameMain;
begin
  try
    Randomize;
    SDL_Init(SDL_INIT_VIDEO);
    if not InitVideo then Exit;
    SDL_WM_SetCaption('Game', 'Game');
    LoadImages;
    TitleScreen;
    NewGame(True);
    MainLoop;
  finally
    SDL_Quit;
  end;
end;

begin
  {$ifdef AROS}
  arosc_static_link.AROSC_Init(@GameMain);
  {$else}
  GameMain;
  {$endif}
end.
