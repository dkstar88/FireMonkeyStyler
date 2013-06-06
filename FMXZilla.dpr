program FMXZilla;

uses
  FMX.Forms,
  uFmxZillaMain in 'uFmxZillaMain.pas' {frmMonkeyzilla},
  ControlEditor in 'ControlEditor.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMonkeyzilla, frmMonkeyzilla);
  Application.Run;
end.
