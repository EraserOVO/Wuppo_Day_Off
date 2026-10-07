@echo off
setlocal
if not defined GODOT set "GODOT=godot"
call "%~dp0prepare_game.cmd"
if errorlevel 1 exit /b 1
start "" "%GODOT%" --path "%~dp0."
