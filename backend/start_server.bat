@echo off
echo 正在啟動後端服務器...
cd /d %~dp0
uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause

