program WinDomina;

uses
  Vcl.Forms,
  WinDomina.Form.Main in 'WinDomina.Form.Main.pas' {MainForm},
  WinDomina.Types in 'WinDomina.Types.pas',
  WinDomina.WindowTools in 'WinDomina.WindowTools.pas',
  WinDomina.Layer in 'WinDomina.Layer.pas',
  WinDomina.Layer.Grid in 'WinDomina.Layer.Grid.pas',
  WinDomina.Layer.Mover in 'WinDomina.Layer.Mover.pas',
  WinDomina.Registry in 'WinDomina.Registry.pas',
  WinDomina.KBHKLib in 'WinDomina.KBHKLib.pas',
  WinDomina.Types.Drawing in 'WinDomina.Types.Drawing.pas',
  WinDomina.Form.Log in 'WinDomina.Form.Log.pas' {LogForm},
  Localization in '..\..\Localization\Localization.pas',
  Localization.VCL.CommonBinding in '..\..\Localization\Localization.VCL.CommonBinding.pas',
  ProcedureHook in '..\..\Localization\ProcedureHook.pas',
  SendInputHelper in '..\..\SendInputHelper\SendInputHelper.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
