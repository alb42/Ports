unit Unit1;

{$mode delphi}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  RayTracer, SyncObjs;

type

  { TMyThread }

  TMyThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    Image1: TImage;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    sc  : Scene;
    rt  : RayTracerEngine;
    s   : String;
    bmp1 : Graphics.TBitmap;
    bmp2 : Graphics.TBitmap;
    bmp : Graphics.TBitmap;
    img : Graphics.TBitmap;
    //t1,t2: Int64;
    Offset: Integer;
    MyThread: TMyThread;
    Crit: TCriticalSection;
  public
    procedure SwapBitmaps;
  end;



var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TMyThread }

procedure TMyThread.Execute;
begin
  repeat

    try
    form1.sc.xcamera.pos.z :=  form1.sc.xcamera.pos.z + 0.1 * form1.Offset;
    form1.sc.xcamera.pos.x :=  form1.sc.xcamera.pos.x + 0.1 * form1.Offset;
    if Abs(form1.sc.xcamera.pos.z - 4) > 4 then
      form1.Offset := -form1.Offset;
    Form1.Img.Clear;
    Form1.Img.SetSize(200, 200);
    Form1.Img.PixelFormat := pf32bit;
    form1.rt.render(form1.sc, Form1.img);

    except
      writeln('exception');
    end;
    //Synchronize(Form1.SwapBitmaps);
    Form1.SwapBitmaps;
    if Terminated then
      Break;
  until Terminated;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Crit := TCriticalSection.Create;
  bmp1 := Graphics.TBitmap.Create;
  bmp1.SetSize(200,200);
  bmp1.PixelFormat := pf32bit;
  bmp2 := Graphics.TBitmap.Create;
  bmp2.SetSize(200,200);
  bmp2.PixelFormat := pf32bit;
  bmp := bmp1;
  img := bmp2;
  sc := Scene.Create();
  rt := RayTracerEngine.Create();
  Offset := -1;
  //sw := TStopWatch.Create;

  //sw.Start;

  //sw.Stop;

  //bmp.SaveToFile('delphi-ray-tracer.bmp');
  MyThread := TMyThread.Create(True);
  MyThread.FreeOnTerminate:=False;
  MYThread.Start;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  MyThread.Terminate;
  MyThread.WaitFor;
  MyThread.Free;
  //bmp.SaveToFile('delphi-ray-tracer1.bmp');
  sc.Free;
  rt.Free;
  bmp.Free;
  Crit.Free;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled:=False;
  Crit.Enter;
  Image1.Picture.Bitmap.Assign(Bmp);
  Crit.Leave;
  Image1.Invalidate;
end;

procedure TForm1.SwapBitmaps;
var
  c: TBitmap;
begin
  Crit.Enter;
  c := Img;
  Img := Bmp;
  Bmp := c;
  Timer1.Enabled:=True;
  Crit.Leave;
end;

end.

