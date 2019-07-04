unit ProcedureHook;

interface

uses
	Classes, Windows, SysUtils;

type
	POverwrittenData = ^TOverwrittenData;
	TOverwrittenData = record
		Location:Pointer;
		OldCode:array[0..6] of Byte;
	end;

	procedure OverwriteProcedure(OldProcedure, NewProcedure:Pointer; Data:POverwrittenData = nil);
	procedure RestoreProcedure(OriginalProc:Pointer; Data:TOverwrittenData);

implementation

procedure OverwriteProcedure(OldProcedure, NewProcedure:Pointer; Data:POverwrittenData = nil);
{ OverwriteProcedure originally from Igor Siticov }
{ Modified by Jacques Garcia Vazquez }
var
	x:PAnsiChar;
	y:Integer;
	ov2, ov:Cardinal;
	p:Pointer;
begin
	if OldProcedure = nil then
	begin
		Data.Location := nil;
		Exit;
	end;

	if Assigned(Data) then
		if Data.Location <> nil then
			Exit; { procedure already overwritten }

	// need six bytes in place of 5
	x:=PAnsiChar(OldProcedure);
	if not VirtualProtect(Pointer(x), 6, PAGE_EXECUTE_READWRITE, @ov) then
		RaiseLastOSError;

	// if a jump is present then a redirect is found
	// $FF25 = jmp dword ptr [xxx]
	// This redirect is normally present in bpl files, but not in exe files
	p:=OldProcedure;

	if Word(p^) = $25FF then
	begin
		Inc(Integer(p), 2); // skip the jump
		// get the jump address p^ and dereference it p^^
		p:=Pointer(Pointer(p^)^);

		// release the memory
		if not VirtualProtect(Pointer(x), 6, ov, @ov2) then
			RaiseLastOSError;

		// re protect the correct one
		x:=PAnsiChar(p);

		if not VirtualProtect(Pointer(x), 6, PAGE_EXECUTE_READWRITE, @ov) then
			RaiseLastOSError;
	end;

	if Assigned(Data) then
	begin
		Move(x^, Data.OldCode, 6);
		{ Assign Location last so that Location <> nil only if OldCode is properly initialized. }
		Data.Location:=x;
	end;

	x[0]:=AnsiChar($E9);
	y:=Integer(NewProcedure) - Integer(p) - 5;
	x[1]:=AnsiChar(y and 255);
	x[2]:=AnsiChar((y shr 8) and 255);
	x[3]:=AnsiChar((y shr 16) and 255);
	x[4]:=AnsiChar((y shr 24) and 255);

	if not VirtualProtect(Pointer(x), 6, ov, @ov2) then
		RaiseLastOSError;
end;

procedure RestoreProcedure(OriginalProc:Pointer; Data:TOverwrittenData);
var
	ov, ov2:Cardinal;
begin
	if Data.Location = nil then
		Exit;

	if not VirtualProtect(Data.Location, 6, PAGE_EXECUTE_READWRITE, @ov) then
		RaiseLastOSError;

	Move(Data.OldCode, Data.Location^, 6);

	if not VirtualProtect(Data.Location, 6, ov, @ov2) then
		RaiseLastOSError;
end;

end.
