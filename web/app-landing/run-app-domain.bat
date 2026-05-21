@echo off
cd /d "%~dp0"
echo.
echo [SGQ] Deploy app landing to https://app.sagp-qp.com
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-app-domain.ps1"
echo.
pause
