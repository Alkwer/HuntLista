@echo off
title Hunt Lista Updater
cd /d "%~dp0"

echo.
echo  Uruchamiam updater...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-HuntLista.ps1"

if errorlevel 1 (
    echo.
    echo  Cos poszlo nie tak. Skopiuj komunikat bledu i napisz na Discordzie.
    echo.
    pause
)
