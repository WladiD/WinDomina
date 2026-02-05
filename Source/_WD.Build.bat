@echo off
setlocal
pushd %~dp0
REM ==================================================================================
REM WinDomina Build Script
REM Wraps DPT.exe to build the specific projects.
REM ==================================================================================

REM Define path to the DPT tool
set "DPT_EXE=..\Lib\WDDelphiTools\Projects\DPT\DPT.exe"

if not exist "%DPT_EXE%" (
    echo ERROR: DPT tool not found at %DPT_EXE%
    echo Please ensure the submodule is initialized and DPT is built.
    exit /b 1
)

echo.
echo =================================================================================
echo Building kbhk.dll (Hook Library)...
echo =================================================================================
"%DPT_EXE%" RECENT Build "kbhk.dproj" "Win32" "Release"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build kbhk.dproj
    exit /b %ERRORLEVEL%
)

echo.
echo =================================================================================
echo Building WinDomina.exe (Main Application)...
echo =================================================================================
"%DPT_EXE%" RECENT Build "WinDomina.dproj" "Win32" "Release"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build WinDomina.dproj
    exit /b %ERRORLEVEL%
)

echo.
echo =================================================================================
echo WinDomina Build Complete.
echo =================================================================================
popd
endlocal
