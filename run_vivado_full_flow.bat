@echo off
rem Helper to launch Vivado with an absolute path to the run_full_flow.tcl
rem Usage: run_vivado_full_flow.bat "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"

setlocal

if "%~1"=="" (
  echo Usage: %~nx0 "C:\Path\To\Vivado\bin\vivado.bat"
  echo Example: %~nx0 "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
  exit /b 1
)

set VIVADO_BIN=%~1

rem Resolve repo root (script lives in project root)
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

set ABS_TCL=%SCRIPT_DIR%\scripts\run_full_flow.tcl

if not exist "%ABS_TCL%" (
  echo ERROR: Cannot find %ABS_TCL%
  exit /b 2
)

echo Launching Vivado using: %VIVADO_BIN%
echo Using TCL script: %ABS_TCL%

"%VIVADO_BIN%" -mode tcl -source "%ABS_TCL%"

endlocal
