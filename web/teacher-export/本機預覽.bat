@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 啟動本機預覽: http://localhost:8080
echo 按 Ctrl+C 結束
python -m http.server 8080
