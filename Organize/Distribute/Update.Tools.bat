@echo off

REM Updates the tools contained in the same named sub folder

SET SELF_PATH=%~dp0
SET TOOLS_PATH=%SELF_PATH%Tools\

CALL "%TOOLS_PATH%ReadINI.cmd" Config.ini Path WDDelphiToolsWC
SET WDDT_WC_PATH=%value%

IF EXIST "%WDDT_WC_PATH%" (
  REM Copy the command line tool FileVersion. This is used to fetch the version of a exe.
  COPY /Y "%WDDT_WC_PATH%Projects\FileVersionCmd\FileVersion.exe" "%TOOLS_PATH%"
)