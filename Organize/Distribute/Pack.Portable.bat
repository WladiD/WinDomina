@ECHO OFF

SET SELF_PATH=%~dp0
SET TOOLS_PATH=%SELF_PATH%Tools\
SET TEMP_PATH=%SELF_PATH%Temp\

IF NOT EXIST "%TEMP_PATH%" MKDIR "%TEMP_PATH%"

REM Get the Runtime path from the config.ini, where it may be relative
call "%TOOLS_PATH%ReadINI.cmd" Config.ini Path Runtime
SET RUNTIME_PATH=%value%
PUSHD %RUNTIME_PATH%
SET RUNTIME_PATH=%CD%\
POPD

REM Determine the version of the WinDomina.exe
"%TOOLS_PATH%FileVersion.exe" "%RUNTIME_PATH%WinDomina.exe" "%%FileMajor%%.%%FileMinor%%.%%FileRelease%%" > WD_VERSION.temp
set /p WD_VERSION=<WD_VERSION.temp
DEL WD_VERSION.temp
ECHO %WD_VERSION%

ECHO Prepare portable release for v%WD_VERSION%
SET PACK_PATH=%TEMP_PATH%WinDomina_v%WD_VERSION%\

REM Clear the temp pack path
IF EXIST "%PACK_PATH%" RD /S /Q "%PACK_PATH%"
MKDIR %PACK_PATH%

ECHO Runtime-Path : %RUNTIME_PATH%
ECHO Pack-Path    : %PACK_PATH%

REM Copy all required files for the release
COPY "%RUNTIME_PATH%WinDomina.exe" "%PACK_PATH%"
COPY "%RUNTIME_PATH%kbhk.dll" "%PACK_PATH%"
MKDIR "%PACK_PATH%common"
COPY "%RUNTIME_PATH%common\Lang.de.ini" "%PACK_PATH%common\"
COPY "%RUNTIME_PATH%common\Lang.en.ini" "%PACK_PATH%common\"

CALL "%TOOLS_PATH%ReadINI.cmd" Config.ini File ReadmePortable
COPY "%value%" "%PACK_PATH%"

CALL "%TOOLS_PATH%ReadINI.cmd" Config.ini Path SevenZip
SET SEVENZIP_PATH=%value%

CALL "%TOOLS_PATH%ReadINI.cmd" Config.ini Path OutputPortable
SET OUTPUT_PATH=%value%

IF NOT EXIST "%OUTPUT_PATH%" MKDIR "%OUTPUT_PATH%"

SET PORTABLE_ZIP=%OUTPUT_PATH%WinDomina_v%WD_VERSION%_portable.zip
IF EXIST %PORTABLE_ZIP% DEL %PORTABLE_ZIP%

"%SEVENZIP_PATH%7z" a -tzip -mx9 "%PORTABLE_ZIP%" "%PACK_PATH%"