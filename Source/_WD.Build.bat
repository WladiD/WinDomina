@echo off
setlocal
REM ==================================================================================
REM WinDomina Build Script
REM Wraps Lib/WDDelphiTools/_BuildBase.bat to build the specific projects.
REM ==================================================================================

REM Define path to the base build script (relative to Source folder)
set "BASE_BUILD_SCRIPT=..\Lib\WDDelphiTools\_BuildBase.bat"

if not exist "%BASE_BUILD_SCRIPT%" (
    echo ERROR: Base build script not found at %BASE_BUILD_SCRIPT%
    echo Please ensure the submodule is initialized: git submodule update --init --recursive
    exit /b 1
)

REM ----------------------------------------------------------------------------------
REM 1. Build the Keyboard Hook DLL (kbhk.dll)
REM ----------------------------------------------------------------------------------
echo.
echo =================================================================================
echo Building kbhk.dll (Hook Library)...
echo =================================================================================
call "%BASE_BUILD_SCRIPT%" "kbhk.dproj" "Win32" "Release"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build kbhk.dproj
    exit /b %ERRORLEVEL%
)

REM ----------------------------------------------------------------------------------
REM 2. Build the Main Application (WinDomina.exe)
REM ----------------------------------------------------------------------------------
echo.
echo =================================================================================
echo Building WinDomina.exe (Main Application)...
echo =================================================================================
call "%BASE_BUILD_SCRIPT%" "WinDomina.dproj" "Win32" "Release"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to build WinDomina.dproj
    exit /b %ERRORLEVEL%
)

echo.
echo =================================================================================
echo WinDomina Build Complete.
echo =================================================================================
endlocal
