@echo off
rem Helper to run the Python AI engine with VIVADO_BIN set for Windows
rem Usage: run_ai.bat "C:\AMDDesignTools\2025.2\Vivado\bin"

setlocal

if "%~1"=="" (
  echo Usage: %~nx0 "C:\Path\To\Vivado\bin"
  exit /b 1
)

set VIVADO_BIN=%~1

rem Ensure Python is on PATH; call python launcher
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

pushd "%SCRIPT_DIR%"
set PATH=%VIVADO_BIN%;%PATH%

echo Running AI engine with VIVADO_BIN=%VIVADO_BIN%
python "%SCRIPT_DIR%\ai\vivado_ai.py"

popd
endlocal
@echo off
REM =================================================================
REM I2C AI Verification — Vivado Auto-Setup Helper
REM This script finds and configures Vivado, then runs the AI engine
REM =================================================================

echo.
echo ===================================================================
echo  I2C AI Verification — Vivado Setup Helper
echo ===================================================================
echo.

REM Check common Vivado locations
setlocal enabledelayedexpansion

set VIVADO_FOUND=0
set VIVADO_PATH=

echo Searching for Vivado installation...
echo.

REM Search in common locations
for %%D in (
    "C:\Xilinx\Vivado\2024.1\bin"
    "C:\Xilinx\Vivado\2023.2\bin"
    "C:\Xilinx\Vivado\2023.1\bin"
    "D:\Xilinx\Vivado\2024.1\bin"
    "D:\Xilinx\Vivado\2023.2\bin"
) do (
    if exist "%%D\xvlog.bat" (
        set VIVADO_PATH=%%D
        set VIVADO_FOUND=1
        echo ✓ Found Vivado at: %%D
        goto FOUND
    )
)

:FOUND
if %VIVADO_FOUND%==0 (
    echo.
    echo ✗ Vivado NOT found in common locations!
    echo.
    echo Please provide your Vivado installation path manually:
    echo.
    set /p VIVADO_PATH="Enter your Vivado bin directory (e.g., C:\Xilinx\Vivado\2024.1\bin): "
    
    if not exist "!VIVADO_PATH!\xvlog.bat" (
        echo.
        echo ✗ ERROR: xvlog.bat not found at !VIVADO_PATH!
        echo Please verify the path is correct.
        echo.
        pause
        exit /b 1
    )
    echo ✓ Using Vivado at: !VIVADO_PATH!
)

echo.
echo Adding Vivado to PATH: %VIVADO_PATH%
set PATH=%VIVADO_PATH%;%PATH%

echo Verifying xvlog...
where xvlog >nul 2>&1
if errorlevel 1 (
    echo ✗ ERROR: Could not verify xvlog!
    echo Please check your Vivado installation.
    pause
    exit /b 1
)
echo ✓ xvlog is ready!

echo.
echo ===================================================================
echo  Starting AI Coverage Engine...
echo ===================================================================
echo.

REM Run the AI engine with the found Vivado path
python3 ai\vivado_ai.py --strategy genetic --target 100 --runs 15

if errorlevel 1 (
    echo.
    echo ✗ AI Engine failed!
    pause
    exit /b 1
)

echo.
echo ✓ AI Engine completed successfully!
echo.
pause
