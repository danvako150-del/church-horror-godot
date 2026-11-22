@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Run.ps1" -Test
if errorlevel 1 pause
