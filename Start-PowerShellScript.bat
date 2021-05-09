REM Runs a script PowerShell from any location
@echo off
chcp 1251
REM Restart the script in background. Comment out the next line if not needed
if "%~1" == "" (start "" /min "%comspec%" /c "%~f0" any_word & exit /b)
REM The location of the script to run
set LocationScript=TestFolder\TestScript.ps1
REM Get current location
set CurrentLocation=%~dp0
REM Run the script PowerShell
powershell.exe -NoLogo -NoExit -WindowStyle Normal -ExecutionPolicy Bypass -File "%CurrentLocation%%LocationScript%"
