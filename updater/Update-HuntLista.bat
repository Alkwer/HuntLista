@echo off
title Hunt Lista Updater
cd /d "%~dp0"

echo.
echo  Uruchamiam updater v1.2...
echo.

if /I "%1"=="-reset" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-HuntLista.ps1" -reset
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-HuntLista.ps1" %*
)

if errorlevel 1 (
    echo.
    echo  Cos poszlo nie tak.
    echo  Sprobuj: skasuj updater-config.txt i odpal ponownie.
    echo  Albo: Update-HuntLista.bat -reset
    echo.
    pause
)
