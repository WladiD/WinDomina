unit WinDomina.Form.Number;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls;

type
  TNumberForm = class(TForm)
    Shape1: TShape;
    MainLabel: TLabel;
  private
    FAssignedToWindow: HWND;
  public
    property AssignedToWindow: HWND read FAssignedToWindow write FAssignedToWindow;
  end;

implementation

{$R *.dfm}

end.
