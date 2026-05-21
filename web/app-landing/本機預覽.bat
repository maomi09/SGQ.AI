@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Local preview: http://localhost:8081
echo Press Ctrl+C to stop
py -m http.server 8081
