@echo off
title Hunt Lista Auto Updater
cd /d "%~dp0"
echo Uruchamiam Auto Updater...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HuntLista-AutoUpdater.ps1"
if errorlevel 1 pause
