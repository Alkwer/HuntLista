@echo off
title Hunt Lista Updater
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-HuntLista.ps1"
