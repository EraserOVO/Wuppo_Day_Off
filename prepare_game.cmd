@echo off
setlocal
if not defined GODOT set "GODOT=godot"
if not exist "%GODOT%" (
 where "%GODOT%" >nul 2>&1
 if errorlevel 1 (
  echo Godot 4.7.2 was not found. Add it to PATH or set the GODOT environment variable.
  echo You can also open project.godot from the Godot Project Manager.
  pause
  exit /b 1
 )
)
for %%I in ("%GODOT%") do set "TASK_IMPORT_ENGINE=%%~dpnI_console.exe"
if not exist "%TASK_IMPORT_ENGINE%" set "TASK_IMPORT_ENGINE=%GODOT%"
if not exist "%~dp0.godot" mkdir "%~dp0.godot"
echo Preparing game assets...
"%TASK_IMPORT_ENGINE%" --headless --editor --path "%~dp0." --import > "%~dp0.godot\startup_import.log" 2>&1
if errorlevel 1 goto import_failed
findstr /C:"SCRIPT ERROR:" /C:"Failed to load script" /C:"Failed to load resource" /C:"Failed to import" "%~dp0.godot\startup_import.log" >nul
if not errorlevel 1 goto import_failed
exit /b 0
:import_failed
echo Game preparation failed. Details:
type "%~dp0.godot\startup_import.log"
pause
exit /b 1
