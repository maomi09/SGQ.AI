@echo off
cd /d "%~dp0"
echo.
echo [SGQ] AWS deploy starting...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-aws.ps1"
echo.
pause
