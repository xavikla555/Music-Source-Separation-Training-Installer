@echo off
setlocal enabledelayedexpansion
title MSST-WebUI - Installer (Micromamba Portable)

echo =======================================================
echo  Music Source Separation Training UI - Installer
echo  (Portable Micromamba Edition)
echo =======================================================
echo.

REM =======================================================
REM  1. CONFIGURATION AND PATH SETTINGS
REM =======================================================
REM Define the installation base directory
set "INSTALL_DIR=%~dp0"
REM Remove trailing backslash if present
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"

REM Project configuration
set "REPO_NAME=MSST-WebUI"
set "REPO_DIR=%INSTALL_DIR%\%REPO_NAME%"

REM Micromamba portable paths - NOW INSIDE REPO DIR
set "MICROMAMBA_DIR=%REPO_DIR%\micromamba"
set "MAMBA_EXE=%MICROMAMBA_DIR%\micromamba.exe"
set "MAMBA_ROOT_PREFIX=%MICROMAMBA_DIR%\root"
set "ENV_DIR=%REPO_DIR%\env"

set "REPO_URL=https://github.com/SUC-DriverOld/MSST-WebUI.git"
set "MICROMAMBA_URL=https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-win-64.exe"

REM =======================================================
REM  2. PERFORMANCE TIMER START
REM =======================================================
set "t=%TIME: =0%"
set /a startHour=1%t:~0,2% %% 100
set /a startMin=1%t:~3,2% %% 100
set /a startSec=1%t:~6,2% %% 100
set /a startTotal=startHour*3600+startMin*60+startSec

REM =======================================================
REM  3. CLEANUP / VALIDATION PREVIOUS INSTALLATIONS
REM =======================================================
if exist "%REPO_DIR%" (
    echo [WARNING] Folder "%REPO_NAME%" already exists.
    set /p "CHOICE=Do you want to DELETE the existing folder and reinstall? (y/n): "
    if /i "!CHOICE!"=="y" (
        echo [PROCESS] Removing old installation...
        rmdir /s /q "%REPO_DIR%"
        echo [SUCCESS] Cleanup complete.
    ) else (
        echo [INFO] Installation canceled by user to protect existing folder.
        pause
        exit /b 1
    )
)
echo.

REM =======================================================
REM  4. PRE-CREATE REPO DIR AND MICROMAMBA SETUP
REM =======================================================
REM We need to create the repo dir first since micromamba now lives inside it
if not exist "%REPO_DIR%" mkdir "%REPO_DIR%"

if exist "%MAMBA_EXE%" (
    echo [INFO] Micromamba binary is already present. Skipping download...
) else (
    echo [PROCESS] Downloading portable Micromamba EXE...
    if not exist "%MICROMAMBA_DIR%" mkdir "%MICROMAMBA_DIR%"
    
    curl -L "%MICROMAMBA_URL%" -o "%MAMBA_EXE%"
    
    if not exist "%MAMBA_EXE%" (
        echo [ERROR] Micromamba download failed.
        goto :error_exit
    )
    echo [SUCCESS] Micromamba downloaded.
)

REM =======================================================
REM  5. REPOSITORY CLONING AND SETUP
REM =======================================================
echo [PROCESS] Checking Git installation...
set "GIT_CMD=git"
git --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] System Git not found. Installing portable Git via Micromamba...
    "%MAMBA_EXE%" create -n base git -c conda-forge -y
    if errorlevel 1 (
        echo [ERROR] Failed to install Git.
        goto :error_exit
    )
    set "GIT_CMD=%MAMBA_ROOT_PREFIX%\Library\bin\git.exe"
)

echo [PROCESS] Cloning MSST-WebUI repository...
"!GIT_CMD!" clone --recurse-submodules "%REPO_URL%" "%REPO_DIR%_temp"
if errorlevel 1 (
    echo [ERROR] Failed to clone the repository.
    goto :error_exit
)

echo [PROCESS] Moving files to main directory...
REM Robocopy Exit Codes: 0-7 are success (various states), 8+ are critical errors.
robocopy "%REPO_DIR%_temp" "%REPO_DIR%" /E /MOVE /NFL /NDL /NJH /NJS
if %errorlevel% GEQ 8 (
    echo [ERROR] Robocopy failed with exit code %errorlevel%.
    rmdir /s /q "%REPO_DIR%_temp"
    goto :error_exit
)

REM We remove the temp folder if robocopy left it (sometimes empty folders remain)
if exist "%REPO_DIR%_temp" rmdir /s /q "%REPO_DIR%_temp"
echo [SUCCESS] Repository prepared.
echo.

REM =======================================================
REM  6. ENVIRONMENT CREATION
REM =======================================================
echo [PROCESS] Creating local Micromamba environment (Python 3.10)...
"%MAMBA_EXE%" create -p "%ENV_DIR%" python=3.10 -c conda-forge -y
if errorlevel 1 (
    echo [ERROR] Failed to create the environment.
    goto :error_exit
)
echo [SUCCESS] Environment created at: %ENV_DIR%
echo.

REM =======================================================
REM  7. DEPENDENCY INSTALLATION (PyTorch & PIP)
REM =======================================================
echo [PROCESS] Detecting CUDA...

REM Default settings
set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu124"
set "CUDA_DETECTED=0"

nvidia-smi >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=9" %%a in ('nvidia-smi ^| findstr /C:"CUDA Version:"') do set "FULL_CUDA_VER=%%a"
    
    for /f "tokens=1,2 delims=." %%a in ("!FULL_CUDA_VER!") do (
        set /a CUDA_MAJOR=%%a
        set /a CUDA_MINOR=%%b
    )

    echo [INFO] Detected CUDA Version: !FULL_CUDA_VER!
    set "CUDA_DETECTED=1"

    REM Version selection logic for RTX 50XX and newer drivers
    if !CUDA_MAJOR! geq 13 (
        echo [INFO] CUDA 13+ detected. Forcing CUDA 12.8 index for Blackwell support.
        set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu128"
    ) else if !CUDA_MAJOR! equ 12 (
        if !CUDA_MINOR! geq 5 (
            echo [INFO] CUDA 12.5+ detected. Using CUDA 12.8 index.
            set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu128"
        ) else (
            echo [INFO] CUDA 12.0-12.4 detected. Using CUDA 12.4 index.
            set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu124"
        )
    ) else if !CUDA_MAJOR! equ 11 (
        echo [INFO] Legacy GPU detected. Using CUDA 11.8 index.
        set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu118"
    )
) else (
    echo [WARNING] NVIDIA GPU not found. Falling back to CPU.
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cpu"
)

echo [PROCESS] Installing PyTorch suite...
echo [URL] Target: %PYTORCH_INDEX%

"%MAMBA_EXE%" run -p "%ENV_DIR%" pip install --no-cache-dir torch torchvision torchaudio --index-url "%PYTORCH_INDEX%" --extra-index-url https://pypi.org/simple
if errorlevel 1 (
    echo [ERROR] PyTorch installation failed.
    goto :error_exit
)

echo [PROCESS] Cleaning requirements.txt (precise mode)...

powershell -Command "$exclude = @('torch', 'torchvision', 'torchaudio'); (Get-Content '%REPO_DIR%\requirements.txt') | Where-Object { $_ -notin $exclude -and $_ -notmatch '^torch[>= ]' } | Out-File -Encoding UTF8 '%REPO_DIR%\requirements_clean.txt'"

if errorlevel 1 (
    echo [ERROR] Failed to clean requirements.txt.
    goto :error_exit
)

echo [PROCESS] Installing project requirements...
"%MAMBA_EXE%" run -p "%ENV_DIR%" pip install --no-cache-dir -r "%REPO_DIR%\requirements_clean.txt"

REM Remove temporary file after successful installation
del "%REPO_DIR%\requirements_clean.txt"

REM ----------- Librosa FIX -----------
echo [PROCESS] Applying Librosa version fix...
cd /d "%REPO_DIR%"
"%MAMBA_EXE%" run -p "%ENV_DIR%" pip uninstall librosa -y
"%MAMBA_EXE%" run -p "%ENV_DIR%" pip install --no-cache-dir "tools/webUI_for_clouds/librosa-0.9.2-py3-none-any.whl"
if errorlevel 1 (
    echo [ERROR] Failed to install Librosa wheel.
    goto :error_exit
)
REM -----------------------------------

echo [SUCCESS] Dependencies setup complete.
echo.

REM =======================================================
REM  8. CREATE RUN-GUI LAUNCHER
REM =======================================================
echo [PROCESS] Creating 'run-gui.bat' launcher...
set "OUT_FILE=%REPO_DIR%\run-gui.bat"

(
echo @echo off
echo title MSST GUI Launcher
echo.
echo REM Path resolution for portable execution
echo set "REPO_DIR=%%~dp0"
echo if "%%REPO_DIR:~-1%%"=="\" set "REPO_DIR=%%REPO_DIR:~0,-1%%"
echo set "ENV_DIR=%%REPO_DIR%%\env"
echo set "MICROMAMBA_DIR=%%REPO_DIR%%\micromamba"
echo set "MAMBA_EXE=%%MICROMAMBA_DIR%%\micromamba.exe"
echo set "MAMBA_ROOT_PREFIX=%%MICROMAMBA_DIR%%\root"
echo.
echo echo Launching GUI via Micromamba...
echo cd /d "%%REPO_DIR%%"
echo "%%MAMBA_EXE%%" run -p "%%ENV_DIR%%" python webUI.py
echo.
echo pause
) > "%OUT_FILE%"

if exist "%OUT_FILE%" (
    echo [SUCCESS] Launcher created: "%OUT_FILE%"
) else (
    echo [ERROR] Failed to create launcher script.
    goto :error_exit
)
echo.

REM =======================================================
REM  9. INSTALLATION SUMMARY AND TIMER END
REM =======================================================
set "t=%TIME: =0%"
set /a endHour=1%t:~0,2% %% 100
set /a endMin=1%t:~3,2% %% 100
set /a endSec=1%t:~6,2% %% 100
set /a endTotal=endHour*3600+endMin*60+endSec

set /a elapsed=endTotal-startTotal
if %elapsed% lss 0 set /a elapsed+=86400

set /a hours=elapsed/3600
set /a minutes=(elapsed%%3600)/60
set /a seconds=elapsed%%60

echo =======================================================
echo  Installation finished in %hours%h %minutes%m %seconds%s.
echo  To start the application, run 'run-gui.bat' inside:
echo  %REPO_NAME%
echo =======================================================
echo.
pause
exit /b 0

REM =======================================================
REM  ERROR HANDLING BLOCK
REM =======================================================
:error_exit
echo.
echo =======================================================
echo  [CRITICAL] Installation aborted due to an error.
echo =======================================================
pause
exit /b 1
