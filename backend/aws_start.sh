#!/bin/bash
# AWS 後端啟動腳本
# 使用 systemd 或 supervisor 管理時，此腳本用於啟動服務

cd "$(dirname "$0")"
source venv/bin/activate

# 使用 uvicorn 啟動 FastAPI 應用
# --host 0.0.0.0 允許從任何 IP 訪問
# --port 8000 使用端口 8000
# --workers 4 使用 4 個 worker 進程（根據 EC2 實例大小調整）
uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 4 \
    --log-level info
