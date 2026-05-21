@echo off
cd /d "%~dp0"
echo.
echo [SGQ] Deploy to https://export.sagp-qp.com
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-export-domain.ps1"
echo.
pause
