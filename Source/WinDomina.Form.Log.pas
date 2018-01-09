unit WinDomina.Form.Log;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TLogForm = class(TForm)
    LogMemo: TMemo;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;

var
  LogForm: TLogForm;

implementation

{$R *.dfm}

procedure TLogForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);

  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
end;

end.
