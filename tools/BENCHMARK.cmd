@echo off
"%~dp0engine\Godot_v4.5.1-stable_win64_console.exe" --path "%~dp0.." --script res://tools/profile-vehicle.gd --resolution 1280x720 --fixed-fps 60 -- --output=perf_user.json
pause
