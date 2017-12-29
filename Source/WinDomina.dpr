program WinDomina;

uses
  Vcl.Forms,
  WinDomina.Main in 'WinDomina.Main.pas' {MainForm},
  WinDomina.Types in 'WinDomina.Types.pas',
  WinDomina.WindowTools in 'WinDomina.WindowTools.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
