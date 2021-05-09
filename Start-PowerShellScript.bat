REM Runs a script PowerShell from any location
REM This batch file must have the same name as the script file.
@echo off
chcp 1251
cls
REM Restarts the script in the background.
if "%~1" == "" (start "" /min "%comspec%" /c "%~f0" any_word & exit /b)
REM The complete name and extension of the batch file
set CompleteName="%~0"
set Extension=%~x0
REM Replace the extension
call set LocationScript=%%CompleteName:%Extension%=.ps1%%
REM Run the script PowerShell
powershell.exe -NoLogo -NoExit -WindowStyle Normal -ExecutionPolicy Bypass -File %LocationScript%
set /p set=
