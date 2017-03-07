program fpcRayTracer;

{$mode delphi}
uses
  {$ifdef linux}
  cthreads,
  {$endif}
  {$ifdef HASAMIGA}
  athreads,
  {$endif}
  Interfaces,
  Forms,
  Graphics,
  SysUtils,
  RayTracer in 'RayTracer.pas', Unit1;

  //t1,t2:Cardinal;
  //sw  : TStopwatch;
begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.run;
end.
