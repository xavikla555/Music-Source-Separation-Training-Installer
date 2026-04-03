@echo off
setlocal enabledelayedexpansion
title Music Source Separation Installer

echo =============================================
echo Welcome to Music Source Separation Installer
echo =============================================
echo.

REM ================== CONFIG ==================
set "INSTALL_DIR=%cd%"
set "REPO_NAME=Music-Source-Separation-Training"
set "REPO_DIR=%INSTALL_DIR%\%REPO_NAME%"
set "ENV_DIR=%REPO_DIR%\env"
set "MINICONDA_DIR=%UserProfile%\Miniconda3"
set "CONDA_EXE=%MINICONDA_DIR%\Scripts\conda.exe"
set "REPO_URL=https://github.com/ZFTurbo/Music-Source-Separation-Training.git"
set "MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-py312_25.11.1-1-Windows-x86_64.exe"
echo.

REM ================ TIMER START ================
set "startTime=%TIME%"
set /a startHour=%TIME:~0,2%
set /a startMin=%TIME:~3,2%
set /a startSec=%TIME:~6,2%
set /a startTotal=startHour*3600+startMin*60+startSec

REM ============ CLEANUP ==================
echo Cleaning up previous installations...
if exist "%REPO_DIR%" (
    rmdir /s /q "%REPO_DIR%"
)
echo Cleanup complete.
echo.

REM ============ INSTALL MINICONDA ============
if exist "%CONDA_EXE%" (
    echo Miniconda already installed. Skipping...
) else (
    echo Downloading Miniconda...
    powershell -Command "& {Invoke-WebRequest -Uri '%MINICONDA_URL%' -OutFile 'miniconda.exe'}"
    if not exist "miniconda.exe" (
        echo ERROR: Miniconda download failed.
        pause
        exit /b 1
    )
    echo Installing Miniconda silently...
    start /wait "" miniconda.exe /InstallationType=JustMe /RegisterPython=0 /S /D=%MINICONDA_DIR%
    if errorlevel 1 (
        echo ERROR: Miniconda installation failed.
        pause
        exit /b 1
    )
    del miniconda.exe
    echo Miniconda installed successfully.
)
echo.

REM ============ CLONE REPOSITORY ============
echo Cloning Music Source Separation repository...
git --version >nul 2>&1
if errorlevel 1 (
    echo Git not found. Installing Git via Conda...
    "%CONDA_EXE%" install -y git
)
git clone --recurse-submodules "%REPO_URL%" "%REPO_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to clone repository.
    pause
    exit /b 1
)
echo Repository cloned successfully.
echo.

REM ========= CREATE CONDA ENVIRONMENT =========
echo Creating Conda environment inside repository...
"%CONDA_EXE%" create --prefix "%ENV_DIR%" python=3.12 -y
if errorlevel 1 (
    echo ERROR: Failed to create Conda environment.
    pause
    exit /b 1
)
echo Conda environment created.
echo.

REM ========== INSTALL DEPENDENCIES ===========
echo Installing Python dependencies...
call "%MINICONDA_DIR%\condabin\conda.bat" activate "%ENV_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to activate Conda environment.
    pause
    exit /b 1
)

REM Install PyTorch with CUDA support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

REM Install other requirements
pip install -r "%REPO_DIR%\requirements.txt"

if errorlevel 1 (
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)
call "%MINICONDA_DIR%\condabin\conda.bat" deactivate
echo Dependencies installed successfully.
echo.

REM ============ CREATE RUN-GUI.BAT ============
echo Creating run-gui.bat in repository folder...
(
echo @echo off
echo title Music Source Separation GUI Launcher
echo.
echo set "REPO_DIR=%%cd%%"
echo set "ENV_DIR=%%REPO_DIR%%\env"
echo set "MINICONDA_DIR=%MINICONDA_DIR%"
echo call "%%MINICONDA_DIR%%\condabin\conda.bat" activate "%%ENV_DIR%%"
echo if errorlevel 1 (
echo     echo ERROR: Failed to activate Conda environment.
echo     pause
echo     exit /b 1
echo )
echo cd /d "%%REPO_DIR%%"
echo python gui.py
echo call "%%MINICONDA_DIR%%\condabin\conda.bat" deactivate
echo pause
) > "%REPO_DIR%\run-gui.bat"
echo run-gui.bat created successfully.
echo.

REM ============ TIMER END ===================
set "endTime=%TIME%"
set /a endHour=%TIME:~0,2%
set /a endMin=%TIME:~3,2%
set /a endSec=%TIME:~6,2%
set /a endTotal=endHour*3600+endMin*60+endSec
set /a elapsed=endTotal-startTotal
if %elapsed% lss 0 set /a elapsed+=86400
set /a hours=elapsed/3600
set /a minutes=(elapsed%%3600)/60
set /a seconds=elapsed%%60

echo Installation completed in %hours%h %minutes%m %seconds%s.
echo.
echo To run the GUI, just double-click run-gui.bat inside "%REPO_DIR%".
echo.
pause
exit /b 0