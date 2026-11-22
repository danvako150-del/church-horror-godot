@echo off
"%~dp0engine\Godot_v4.5.1-stable_win64_console.exe" --path "%~dp0.." --script res://tools/bake-window-reflections.gd --resolution 256x256 --fixed-fps 60
if errorlevel 1 goto failed
"%~dp0engine\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0.." --script res://tools/build-world.gd
if errorlevel 1 goto failed
exit /b 0
:failed
pause
exit /b 1
