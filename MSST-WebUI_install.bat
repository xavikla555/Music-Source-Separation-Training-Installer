@echo off
setlocal enabledelayedexpansion
title MSST-WebUI - Installer

echo =======================================================
echo    Music Source Separation Training UI - Installer
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
set "ENV_DIR=%REPO_DIR%\env"
set "MINICONDA_DIR=%UserProfile%\Miniconda3"
set "CONDA_EXE=%MINICONDA_DIR%\Scripts\conda.exe"
set "REPO_URL=https://github.com/SUC-DriverOld/MSST-WebUI.git"
set "MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-py312_25.11.1-1-Windows-x86_64.exe"

REM =======================================================
REM  2. PERFORMANCE TIMER START
REM =======================================================
set "t=%TIME: =0%"
set /a startHour=1%t:~0,2% %% 100
set /a startMin=1%t:~3,2% %% 100
set /a startSec=1%t:~6,2% %% 100
set /a startTotal=startHour*3600+startMin*60+startSec

REM =======================================================
REM  3. CLEANUP PREVIOUS INSTALLATIONS
REM =======================================================
echo [PROCESS] Cleaning up previous installation folder...
if exist "%REPO_DIR%" (
    rmdir /s /q "%REPO_DIR%"
)
echo [SUCCESS] Cleanup complete.
echo.

REM =======================================================
REM  4. MINICONDA INSTALLATION CHECK/DOWNLOAD
REM =======================================================
if exist "%CONDA_EXE%" (
    echo [INFO] Miniconda is already installed. Skipping download...
) else (
    echo [PROCESS] Miniconda not found. Downloading via curl...
    curl -L -o miniconda.exe "%MINICONDA_URL%"
    
    if not exist "miniconda.exe" (
        echo [ERROR] Miniconda download failed. Please check your internet connection.
        goto :error_exit
    )
    
    echo [PROCESS] Installing Miniconda silently to: %MINICONDA_DIR%
    start /wait "" miniconda.exe /InstallationType=JustMe /RegisterPython=0 /S /D=%MINICONDA_DIR%
    
    if errorlevel 1 (
        echo [ERROR] Miniconda installation failed.
        del miniconda.exe >nul 2>&1
        goto :error_exit
    )
    del miniconda.exe >nul 2>&1
    echo [SUCCESS] Miniconda installed successfully.
)
echo.

REM =======================================================
REM  5. REPOSITORY CLONING AND SETUP
REM =======================================================
echo [PROCESS] Checking Git installation...
set "GIT_CMD=git"
git --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] System Git not found. Installing Git via Conda...
    "%CONDA_EXE%" install -y -c anaconda git
    if errorlevel 1 (
        echo [ERROR] Failed to install Git.
        goto :error_exit
    )
    REM Set path to Conda-installed Git if system Git is unavailable
    set "GIT_CMD=%MINICONDA_DIR%\Library\bin\git.exe"
)

echo [PROCESS] Cloning MSST-WebUI repository...
"!GIT_CMD!" clone --recurse-submodules "%REPO_URL%" "%REPO_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to clone the repository.
    goto :error_exit
)

REM =======================================================
REM  6. CONDA ENVIRONMENT CREATION
REM =======================================================
echo [PROCESS] Creating local Conda environment (Python 3.12)...
"%CONDA_EXE%" create --prefix "%ENV_DIR%" python=3.12 -y
if errorlevel 1 (
    echo [ERROR] Failed to create the Conda environment.
    goto :error_exit
)
echo [SUCCESS] Environment created at: %ENV_DIR%
echo.

REM =======================================================
REM  7. DEPENDENCY INSTALLATION (PyTorch & PIP)
REM =======================================================
echo [PROCESS] Activating environment and detecting CUDA...
call "%MINICONDA_DIR%\condabin\conda.bat" activate "%ENV_DIR%"

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

REM Install PyTorch with priority for the selected CUDA index
pip install torch torchvision torchaudio --index-url %PYTORCH_INDEX% --extra-index-url https://pypi.org/simple

if errorlevel 1 (
    echo [ERROR] PyTorch installation failed.
    goto :error_exit
)

echo [PROCESS] Installing project requirements...
pip install -r "%REPO_DIR%\requirements.txt"
if errorlevel 1 (
    echo [ERROR] Failed to install requirements.txt.
    call "%MINICONDA_DIR%\condabin\conda.bat" deactivate
    goto :error_exit
)

call "%MINICONDA_DIR%\condabin\conda.bat" deactivate
echo [SUCCESS] Dependencies setup complete for RTX 50-series.
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
echo set "MINICONDA_DIR=%MINICONDA_DIR%"
echo.
echo echo Activating environment...
echo call "%%MINICONDA_DIR%%\condabin\conda.bat" activate "%%ENV_DIR%%"
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to activate environment.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Launching GUI...
echo cd /d "%%REPO_DIR%%"
echo python webUI.py
echo.
echo call "%%MINICONDA_DIR%%\condabin\conda.bat" deactivate
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