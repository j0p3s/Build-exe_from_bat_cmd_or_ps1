@echo off
setlocal
:: Example batch script for Build-exe.bat
:: Drag this file onto Build-exe.bat to get Hello.exe

:: Folder of the EXE when built, folder of the script when run directly
if defined EXE_DIR (set "HERE=%EXE_DIR%") else (set "HERE=%~dp0")

echo Hello from a batch script!
echo.
echo Running from : %~dp0
echo Home folder  : %HERE%
echo Arguments    : %*
echo.
pause
exit /b 0
