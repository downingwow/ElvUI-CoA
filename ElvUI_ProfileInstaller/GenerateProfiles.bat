@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo   ElvUI ProfileInstaller - Profile List Generator
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GenerateProfiles.ps1"
set "ERR=%ERRORLEVEL%"

echo.
if not "%ERR%"=="0" (
    echo Generation failed with exit code %ERR%.
) else (
    echo Done. Profiles.lua has been generated.
    echo Start WoW or use /reload if WoW is already running.
)
echo.
pause
exit /b %ERR%
