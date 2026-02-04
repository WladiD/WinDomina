program WinDomina;

uses
{$IFDEF madExcept}
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
{$ENDIF}
  Vcl.Forms,
  WD.Form.Main in 'WD.Form.Main.pas' {MainForm},
  WD.Types in 'WD.Types.pas',
  WD.WindowTools in 'WD.WindowTools.pas',
  WD.Layer in 'WD.Layer.pas',
  WD.Layer.Grid in 'WD.Layer.Grid.pas',
  WD.Layer.Mover in 'WD.Layer.Mover.pas',
  WD.Registry in 'WD.Registry.pas',
  WD.KBHKLib in 'WD.KBHKLib.pas',
  WD.Form.Log in 'WD.Form.Log.pas' {LogForm},
  WD.Form.Settings in 'WD.Form.Settings.pas' {SettingsForm},
  WD.Types.Actions in 'WD.Types.Actions.pas',
  Localization in '..\..\Localization\Localization.pas',
  Localization.VCL.CommonBinding in '..\..\Localization\Localization.VCL.CommonBinding.pas',
  ProcedureHook in '..\..\Localization\ProcedureHook.pas',
  SendInputHelper in '..\..\SendInputHelper\SendInputHelper.pas',
  WindowEnumerator in '..\Lib\WindowEnumerator\WindowEnumerator.pas',
  WD.WindowMatchSnap in 'WD.WindowMatchSnap.pas',
  WD.WindowPositioner in 'WD.WindowPositioner.pas',
  WD.Types.Messages in 'WD.Types.Messages.pas',
  WD.Form.Number in 'WD.Form.Number.pas' {NumberForm},
  WD.KeyTools in 'WD.KeyTools.pas',
  WD.KeyDecorators in 'WD.KeyDecorators.pas',
  WD.Layer.KeyViewer in 'WD.Layer.KeyViewer.pas',
  WD.LangIndex in 'WD.LangIndex.pas',
  WDDT.DelayedMethod in '..\Lib\WDDelphiTools\WDDT.DelayedMethod.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
