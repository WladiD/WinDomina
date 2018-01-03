program WinDomina;

uses
  Vcl.Forms,
  WinDomina.Main in 'WinDomina.Main.pas' {MainForm},
  WinDomina.Types in 'WinDomina.Types.pas',
  WinDomina.WindowTools in 'WinDomina.WindowTools.pas',
  WinDomina.Layer in 'WinDomina.Layer.pas',
  WinDomina.Layer.Grid in 'WinDomina.Layer.Grid.pas',
  WinDomina.Layer.Mover in 'WinDomina.Layer.Mover.pas',
  WinDomina.Registry in 'WinDomina.Registry.pas',
  WinDomina.KBHKLib in 'WinDomina.KBHKLib.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
